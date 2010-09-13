# Copyright (C) 2010 by Knut Franke
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
# KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
# AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

$cells_read_protocoll = nil

class Module
	# Define one or more cells for the target class.
	# This is similar in spirit to attr_accesssor, except that the accessor
	# methods defined contain some
	def cell(*names)
		names.each do |name|
			# the instance variable name as a symbol
			iname = ("@" + name.to_s).to_sym

			# define setter
			define_method((name.to_s + "=").to_sym) do |new_value|
				# avoid notifying observers of non-updates
				if instance_variable_get(iname) == new_value
					return
				end

				old_value = instance_variable_get(iname)
				instance_variable_set(iname, new_value)

				# collect observers of this cell
				observers = []
				begin
					instance_variable_get(:@cells_observers)[name].each do |pattern, block|
						if pattern === new_value
							observers.push block
						end
					end
				rescue NoMethodError, TypeError
				end
				# make sure external observers are always called before updating
				# other cells
				begin
					observers += instance_variable_get(:@cells_internal_observers)[name]
				rescue NoMethodError, TypeError
				end

				# notify observers
				observers.each do |block|
					block.call(new_value, old_value, self, name.to_sym)
				end
			end

			#define getter
			define_method(name.to_sym) do
				# needed by Object#calculate to figure out which cells a formula
				# depends on
				if $cells_read_protocoll
					$cells_read_protocoll.push [self, name]
				end
				instance_variable_get(iname)
			end
		end
	end
end

class Object
	# Register observer &block to be called when one or more cells changes.
	# cell_spec may be the name of a single cell or a sequence of cells.
	# If pattern is given, a new cell value is matched against it (using ===) and
	# only if the match succeeds &block will get called.
	def observe(cell_spec, pattern=Object, &block)
		@cells_observers ||= Hash.new
		if cell_spec.respond_to? :each
			cell_spec.each do |cell|
				@cells_observers[cell] ||= []
				@cells_observers[cell].push [pattern, block]
			end
		else
			@cells_observers[cell_spec] ||= []
			@cells_observers[cell_spec].push [pattern, block]
		end
	end

	# associate attribute dynamically with the formula given by &block
	# i.e. whenever the cells read by &block change, the attribute will be
	# updated
	def calculate(attribute, &block)
		setter = (attribute.to_s + "=").to_sym

		# initialize attribute and determine source cells
		$cells_read_protocoll = []
		send(setter, block.call)

		# register observer for all source cells
		target_obj = self
		$cells_read_protocoll.each do |obj, readvar|
			obj.instance_eval do
				@cells_internal_observers ||= Hash.new
				@cells_internal_observers[readvar] ||= []
				@cells_internal_observers[readvar].push(proc do
					target_obj.send(setter, block.call)
				end)
			end
		end

		# reset source cell protocoll
		$cells_read_protocoll = nil
	end
end

