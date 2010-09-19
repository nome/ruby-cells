$:.unshift '.'
require 'cells'
require 'Qt4'

# A simple model class.
# Imagine some interesting domain logic here.
class Model
	cell :name, :email, :role
	def initialize
		self.role = :name_only
		self.name = "Your Name"
		self.email = "user@example.com"
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

		input_role = Qt::ComboBox.new do
			add_item "Name", Qt::Variant.new(:name_only.to_s)
			add_item "Public Email", Qt::Variant.new(:public_email.to_s)
			self.current_index = find_data(Qt::Variant.new(model.role.to_s))
			connect(SIGNAL "activated(int)") { |index| model.role = item_data(index).to_string.to_sym }
		end
		input_name = Qt::LineEdit.new(model.name) do
			connect(SIGNAL "textChanged(QString)") { model.name = text }
		end
		input_email = Qt::LineEdit.new(model.email) do
			connect(SIGNAL "textChanged(QString)") { model.email = text }
		end
		output = Qt::Label.new do
			# This is the interesting bit:
			calculate(:text) do
				case model.role
				when :public_email
					"#{model.name} <#{model.email}>"
				else
					"#{model.name}"
				end
			end
		end

		self.layout = Qt::VBoxLayout.new do
			add_widget input_role
			add_widget input_name
			add_widget input_email
			add_widget output
		end
	end
end

Qt::Application.new(ARGV) do
	demo = View.new(Model.new)
	demo.show
	exec
end

