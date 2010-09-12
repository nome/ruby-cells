# Copyright (C) 2010 by Knut Franke
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA  02110-1301  USA

$cells_read_protocoll = nil

class Class
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
					observers += instance_variable_get(:@cells_observers)[name]
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
					block.call(old_value, new_value)
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
	# register observer &block to be called when cell changes
	def observe(cell, &block)
		@cells_observers ||= Hash.new
		@cells_observers[cell] ||= []
		@cells_observers[cell].push block
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

