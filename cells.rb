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
	def cell(*names)
		names.each do |name|
			iname = ("@" + name.to_s).to_sym
			define_method((name.to_s + "=").to_sym) do |new_value|
				if instance_variable_get(iname) == new_value
					return
				end
				old_value = instance_variable_get(iname)
				instance_variable_set(iname, new_value)
				observers = []
				begin
					observers += instance_variable_get(:@cells_observers)[name]
				rescue NoMethodError, TypeError
				end
				begin
					observers += instance_variable_get(:@cells_internal_observers)[name]
				rescue NoMethodError, TypeError
				end
				observers.each do |block|
					block.call(old_value, new_value)
				end
			end
			define_method(name.to_sym) do
				if $cells_read_protocoll
					$cells_read_protocoll.push [self, name]
				end
				instance_variable_get(iname)
			end
		end
	end
end

class Object
	def observe(ivar, &block)
		@cells_observers ||= Hash.new
		@cells_observers[ivar] ||= []
		@cells_observers[ivar].push block
	end

	def calculate(ivar, &block)
		$cells_read_protocoll = []
		initval = block.call
		instance_variable_set(("@" + ivar.to_s).to_sym, initval)
		target_obj = self
		$cells_read_protocoll.each do |obj, readvar|
			obj.instance_eval do
				@cells_internal_observers ||= Hash.new
				@cells_internal_observers[readvar] ||= []
				@cells_internal_observers[readvar].push(proc do
					target_obj.send((ivar.to_s + "=").to_sym, block.call)
				end)
			end
		end
		$cells_read_protocoll = nil
	end
end

