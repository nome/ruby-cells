$:.unshift '.'
require 'cells'
require 'Qt4'

# A simple model class.
# Imagine some interesting domain logic here.
class Model
	cell :content
	def initialize
		self.content = "Hello World."
	end
end

# A simple view to match our simple model.
class View < Qt::Widget
	def initialize(model)
		super()

		self.window_title = 'Testing ruby-cells with a model/view application'
		resize(500,100)
		add_action(Qt::Action.new(self) do
			self.shortcuts = Qt::KeySequence.Quit
			connect(SIGNAL :triggered) { Qt::Application.instance.quit }
		end)

		input = Qt::LineEdit.new(model.content) do
			connect(SIGNAL "textChanged(QString)") { model.content = text }
		end
		output = Qt::Label.new do
			# This is the interesting bit:
			calculate(:text) { "+++" + model.content + "+++" }
		end

		self.layout = Qt::VBoxLayout.new do
			add_widget input
			add_widget output
		end
	end
end

Qt::Application.new(ARGV) do
	demo = View.new(Model.new)
	demo.show
	exec
end

