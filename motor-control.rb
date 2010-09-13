#!/usr/bin/ruby
#
# Loosely based on the motor-control.lisp example for CL Cells:
# http://common-lisp.net/cgi-bin/viewcvs.cgi/cells/doc/motor-control.lisp?rev=1.2&root=cells&view=auto
#

$:.unshift '.'
require 'cells'

class Motor
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

testm.observe :status do |old, new|
	puts "Motor status changing from #{old} to #{new}."
end
testm.observe :fuel_pump do |old, new|
	puts "Fuel Pump changing from #{old} to #{new}."
end
testm.observe :temperature do |old, new|
	puts "Motor temperature changing from #{old} to #{new}."
end
testm.observe :temperature, 100..1000 do |old, new|
	puts "BOILING!"
end

tires = 4.times do |i|
	Tire.new(testm).observe :turning do |old, new|
		puts "Tire #{i} turning: #{new}"
	end
end

testm.temperature = 80
testm.temperature = 110
testm.temperature = 90

