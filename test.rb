require 'test/unit'
require 'weakref'
$:.unshift '.'
require 'cells'

class TestDummy
	cell :cell1, :cell2, :cell3, :cell4
end

class CellsTests < Test::Unit::TestCase
	def setup
		@dummy = TestDummy.new
		@dummy.cell1 = 5
		@dummy.calculate(:cell2) do
			@dummy.cell1 * 10
		end
		@dummy.calculate :cell3 do
			case @dummy.cell2
			when 0...25 then :low
			when 25...75 then :medium
			when 75..100 then :high
			else :out_of_range
			end
		end
	end

	# see whether any expected methods are missing
	def test_api
		assert_respond_to @dummy, :cell1, "reader method for cell1 defined"
		assert_respond_to @dummy, :cell2, "reader method for cell2 defined"
		assert_respond_to @dummy, :cell3, "reader method for cell3 defined"
		assert_respond_to @dummy, :cell4, "reader method for cell4 defined"
		assert_respond_to @dummy, :cell1=, "writer method for cell1 defined"
		assert_respond_to @dummy, :cell2=, "writer method for cell2 defined"
		assert_respond_to @dummy, :cell3=, "writer method for cell3 defined"
		assert_respond_to @dummy, :cell4=, "writer method for cell4 defined"
		assert_respond_to @dummy, :observe, "method for registering observers exists"
		assert_respond_to @dummy, :unobserve, "method for deregistering observers exists"
		assert_respond_to @dummy, :calculate, "method for connecting cells exists"
	end

	# test basic observing
	def test_simple_observer
		observer = @dummy.observe(:cell1) { throw :cell1_changed }
		assert_throws :cell1_changed, "simple observer gets called" do
			@dummy.cell1 = 10
		end
	end

	# test observing conditional on a certain pattern
	def test_conditional_observer
		observer = @dummy.observe(:cell1, 0..10) { throw :cell1_changed }
		assert_throws :cell1_changed, "conditional observer gets called" do
			@dummy.cell1 = 2
		end
		assert_nothing_thrown "conditional observer doesn't get called" do
			@dummy.cell1 = 20
		end
	end

	# test automatic updating of dependent cells
	def test_cells_updated
		@dummy.cell1 = 5
		assert_equal 50, @dummy.cell2, "initial value of cell 2"
		assert_equal :medium, @dummy.cell3, "initial value of cell  3"
		@dummy.cell1 = 8
		assert_equal 80, @dummy.cell2, "updated value of cell 2"
		assert_equal :high, @dummy.cell3, "updated value of cell 3"
	end

	# test de-registration of observers
	def test_unobserving
		# simple case: de-register observer completely with object being observed
		observer = @dummy.observe(:cell1) { throw :cell1_changed }
		assert_throws :cell1_changed, "observer registered correctly" do
			@dummy.cell1 = 1
		end
		@dummy.unobserve(observer)
		assert_nothing_thrown "observer de-registered correctly" do
			@dummy.cell1 = 2
		end

		# de-registering only for particular cells
		observer = @dummy.observe([:cell1, :cell4]) { throw :observer_called }
		assert_throws :observer_called, "observer registered on :cell1" do
			@dummy.cell1 = 1
		end
		assert_throws :observer_called, "observer registered on :cell4" do
			@dummy.cell4 = 1
		end
		@dummy.unobserve(observer, :cell1)
		assert_nothing_thrown "observer de-registered on :cell1" do
			@dummy.cell1 = 2
		end
		assert_throws :observer_called, "observer still registered on :cell4" do
			@dummy.cell4 = 2
		end
		@dummy.unobserve(observer)

		# de-registering only for particular patterns
		# registering the same block for different ranges is maybe somewhat unusual,
		# but should work
		unusual_observer = proc { throw :unusual_observer_called }
		assert_same unusual_observer, @dummy.observe(:cell1, 0..10, &unusual_observer)
		assert_same unusual_observer, @dummy.observe(:cell1, 60..100, &unusual_observer)
		assert_throws :unusual_observer_called, "observing low range" do
			@dummy.cell1 = 1
		end
		assert_nothing_thrown "not observing mid range" do
			@dummy.cell1 = 11
		end
		assert_throws :unusual_observer_called, "observing high range" do
			@dummy.cell1 = 61
		end
		@dummy.unobserve(unusual_observer, :cell1, 0..10)
		assert_nothing_thrown "observer de-registered for low range" do
			@dummy.cell1 = 1
		end
		assert_throws :unusual_observer_called, "observer not de-registered for high range" do
			@dummy.cell1 = 61
		end
	end

	# test memory management issues; in particular, observees should never keep
	# observers from being garbage collected
	def test_memory_management
		observer = @dummy.observe(:cell1) { throw :observer_alive }
		ObjectSpace.garbage_collect
		assert_throws :observer_alive, "observer correctly registered and still referenced" do
			@dummy.cell1 = 1
		end
		observer = nil
		ObjectSpace.garbage_collect
		assert_nothing_thrown "observer has been collected by garbage collector" do
			@dummy.cell1 = 2
		end

		# test garbage collection of objects with dependent cells
		observer = TestDummy.new
		observer_weakref = WeakRef.new observer
		assert observer_weakref.weakref_alive?, "check that WeakRef is registered correctly, just in case"
		observer.calculate(:cell1) { @dummy.cell1 * 100 }
		assert_equal 200, observer.cell1, "initial calculation of observer.cell1 works as expected"
		@dummy.cell1 = 10
		assert_equal 1000, observer.cell1, "observer.cell1 gets updated when @dummy.cell1 changes"
		observer = nil
		ObjectSpace.garbage_collect
		assert (not observer_weakref.weakref_alive?), "object with dependent cells has been garbage collected"
	end

	# make sure the bug fixed in commit 8a0e7d doesn't crop up again
	def test_hashmutable_observers
		observer = TestDummy.new
		class << observer
			def hash
				cell1.hash
			end
			def eql? other
				cell1.eql? other.cell1
			end
		end
		observer.calculate(:cell1) { @dummy.cell1 * 100 }
		assert_equal 500, observer.cell1, "initial calculation of observer.cell1"
		assert_equal 500.hash, observer.hash, "hash value follows cell value"
		@dummy.cell1 = 2
		assert_equal 200, observer.cell1, "first update of observer.cell1"
		assert_equal 200.hash, observer.hash, "hash value follows cell value"
		@dummy.cell1 = 3
		assert_equal 300, observer.cell1, "second update of observer.cell1"
		assert_equal 300.hash, observer.hash, "hash value follows cell value"
	end

	# test cell semantics for slicing operators
	def test_slicing
		ary = [1,2,3]
		class << ary
			cell_slicing
		end

		observer = ary.observe { throw :content_changed }
		assert_throws :content_changed, "changing array content calls observer" do
			ary[1] = 20
		end
		ary.unobserve observer

		@dummy.calculate(:cell4) { ary[0] + ary[1] + ary[2] }
		assert_equal 24, @dummy.cell4, "initial calculation based on ary values"
		ary[2] = 30
		assert_equal 51, @dummy.cell4, "cell gets updated when ary changes"

		ary.calculate(:[], 2) { @dummy.cell1 + 1 }
		assert_equal 6, ary[2], "initial calculation of array content"
		@dummy.cell1 = 8
		assert_equal 9, ary[2], "automatic recalculation of array content"
	end

	# cell formulas may branch on a cell value and source different sets of cells
	def test_branching_formulae
		@dummy.cell4 = 4
		dependent = TestDummy.new
		dependent.calculate(:cell1) do
			if @dummy.cell3 == :out_of_range
				@dummy.cell4 * 10
			else
				@dummy.cell2 * 10
			end
		end
		assert_equal 500, dependent.cell1, "initial calculation of dependent cell"
		@dummy.cell1 = 100
		assert_equal 40, dependent.cell1, "taking the other branch"
		@dummy.cell4 = 9
		assert_equal 90, dependent.cell1, "updating a cell sourced only after the branch change"
	end
end
