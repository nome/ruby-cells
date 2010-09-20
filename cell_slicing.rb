$:.unshift '.'
require 'cells'

class Array
	cell_slicing
	cell :value
end

ary = (1..10).to_a
ary2 = (11..20).to_a

observer = ary.observe do |new, old, obj, index|
	puts "#{obj.inspect}#{index} changed from #{old.inspect} to #{new.inspect}"
end
ary[1] = 3
ary[2] = 5

ary2.value = 100

ary.calculate(:[], 3) { ary2.value + ary2[2] }
ary2.value = 200
ary2[2] = 30

ary.calculate(:[], 5..8) { ary2[6..9].map{|i|i*10} }
ary2[7] = 2

ary2.calculate(:value) { ary2[9]*1000 }
ary2[9] = 42
