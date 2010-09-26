#!/usr/bin/ruby
#
# Loosely based on the motor-control.lisp example for CL Cells:
# http://common-lisp.net/cgi-bin/viewcvs.cgi/cells/doc/motor-control.lisp?rev=1.2&root=cells&view=auto
#

$:.unshift '.'
require 'cells'

class Motor
	include Cells
	cell :status, :fuel_pump, :temperature

	def initialize(temperature)
		self.temperature = temperature
		calculate :status do
			if self.temperature < 100
				:on
			else
				:off
			end
		end
		calculate :fuel_pump do
			if self.status == :on
				:open
			else
				:closed
			end
		end
	end
end

class Tire
	include Cells
	cell :turning
	def initialize(motor)
		calculate :turning do
			if motor.status == :on
				:yes
			else
				:no
			end
		end
	end
end

testm = Motor.new(50)

observer = testm.observe [:status, :fuel_pump, :temperature] do |new, old, obj, cell|
	puts "#{cell} changing from #{old} to #{new}."
end
observer2 = testm.observe :temperature, 100..1000 do
	puts "BOILING!"
end

tires = (1..4).map do |i|
	Tire.new(testm).observe :turning do |new|
		puts "Tire #{i} turning: #{new}"
	end
end

testm.temperature = 80
testm.temperature = 110
puts "Testing whether all observers survive garbage collection..."
ObjectSpace.garbage_collect
testm.temperature = 90
puts "Un-observing :temperature..."
testm.unobserve(observer, :temperature)
testm.temperature = 120

