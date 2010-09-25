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

require 'weakref'

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
				old_value = instance_variable_get(iname)
				instance_variable_set(iname, new_value)

				# avoid notifying observers of non-updates
				if old_value == new_value
					return
				end

				# make sure external observers are always called before updating
				# other cells
				begin
					@cells_observers[name].select!{|pattern, block| block.weakref_alive?}
					@cells_observers[name].each do |pattern, block|
						if pattern === new_value
							begin
								block.call(new_value, old_value, self, name.to_sym)
							rescue WeakRef::RefError
								# oops, that was close. block got garbage collected
								# between us cleaning the observer list and trying to
								# call this block. ignore for now; we'll remove it next
								# time around.
							end
						end
					end
				rescue NoMethodError, TypeError
				end

				# update other cells
				begin
					@cells_internal_observers[name].select! { |argsblock, target| target.weakref_alive? }
					@cells_internal_observers[name].each do |argsblock, target|
						begin
							# maybe the change in this cell triggers new dependencies due to a branch on its
							# value; so we call calculate again to update dependencies
							target.calculate(*argsblock[0], &argsblock[1])
						rescue WeakRef::RefError
							# see @cells_observers case above
						end
					end
				rescue NoMethodError, TypeError
				end
			end

			#define getter
			define_method(name.to_sym) do
				# needed by Object#calculate to figure out which cells a formula
				# depends on
				if $cells_read_protocoll
					$cells_read_protocoll.push [self, name.to_sym]
				end
				instance_variable_get(iname)
			end
		end
	end

	# Make slicing operators behave as if each index denoted a cell
	def cell_slicing
		alias_method :cells_slice_assign, :[]=
		alias_method :cells_slice, :[]
		private :cells_slice_assign, :cells_slice

		define_method(:[]=) do |*args|
			index = args[0..-2]
			old_value = cells_slice(*index)
			cells_slice_assign(*args)
			new_value = cells_slice(*index)

			# avoid notifying observers of non-updates
			if old_value == new_value
				return
			end

			begin
				@cells_observers[:[]].select!{|pattern, block| block.weakref_alive?}
				@cells_observers[:[]].each do |pattern, block|
					if pattern === new_value
						begin
							block.call(new_value, old_value, self, index)
						rescue WeakRef::RefError
						end
					end
				end
			rescue NoMethodError, TypeError
			end

			begin
				@cells_internal_observers[:[]].select!{ |argsblock, target| target.weakref_alive? }
				@cells_internal_observers[:[]].each do |argsblock, target|
					begin
						target.calculate(*argsblock[0], &argsblock[1])
					rescue WeakRef::RefError
					end
				end
			rescue NoMethodError, TypeError
			end
		end

		#define getter
		define_method(:[]) do |*args|
			# needed by Object#calculate to figure out which cells a formula
			# depends on
			if $cells_read_protocoll
				$cells_read_protocoll.push([self, :[]])
			end
			cells_slice(*args)
		end
	end
end

class Object
	# Register observer &block to be called when one or more cells changes.
	# Return block; the caller is supposed to keep a reference to the block as long
	# as it's supposed to be executed. Simply registering a block as an observer
	# won't keep it from being garbage collected (it's stored as a WeakRef); and
	# either the block being garbage collected or explicitly de-registered using
	# Object#unobserve will stop the observer from receiving further events.
	# cell_spec may be the name of a single cell or a sequence of cells.
	# If pattern is given, a new cell value is matched against it (using ===) and
	# only if the match succeeds &block will get called.
	def observe(cell_spec=:[], pattern=Object, &block)
		@cells_observers ||= Hash.new
		if cell_spec.respond_to? :each
			cell_spec.each do |cell|
				@cells_observers[cell] ||= []
				@cells_observers[cell].push [pattern, WeakRef.new(block)]
			end
		else
			@cells_observers[cell_spec] ||= []
			@cells_observers[cell_spec].push [pattern, WeakRef.new(block)]
		end
		block
	end

	# De-register an observer block.
	# observer must be equal to the block to be de-registered.
	# If cell_spec or pattern are given and non-nil, they limit the registrations
	# being canceled to the specified cell(s) or pattern.
	def unobserve(observer, cell_spec=nil, pattern=nil)
		return if @cells_observers.nil?
		cells = if cell_spec.nil?
					  @cells_observers.map { |cell,observes| cell }
				  elsif cell_spec.respond_to? :to_a
					  cell_spec.to_a
				  else
					  [cell_spec]
				  end
		@cells_observers.select{ |cell,obervers| cells.include? cell}.each do |cell, observers|
			observers.delete_if{ |pat,block| (pattern.nil? or pattern == pat) and block == observer }
		end
	end

	# associate attribute dynamically with the formula given by &block
	# i.e. whenever the cells read by &block change, the attribute will be
	# updated
	def calculate(*args, &block)
		# initialize attribute and determine source cells
		$cells_read_protocoll = []
		result = block.call

		# register observer for all source cells
		target_obj = self
		$cells_read_protocoll.each do |obj, readvar|
			obj.instance_eval do
				@cells_internal_observers ||= Hash.new
				@cells_internal_observers[readvar] ||= Hash.new
				@cells_internal_observers[readvar][[args,block]] = WeakRef.new(target_obj)
			end
		end

		# reset source cell protocoll
		$cells_read_protocoll = nil

		# finally, update the target attribute
		if args[0] == :[]
			self[*args[1..-1]] = result
		else
			send((args[0].to_s + "=").to_sym, result)
		end
	end
end

