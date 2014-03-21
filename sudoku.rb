require 'sinatra'
require 'sinatra/partial' 
set :partial_template_engine, :erb
require 'newrelic_rpm'
require_relative './lib/sudoku.rb'
require_relative './lib/cell.rb'
require_relative './helpers/application.rb'
require 'rack-flash'
use Rack::Flash

enable :sessions
set :session_secret, "Your face is gross, you eat white toast"

def random_sudoku
  seed = (1..9).to_a.shuffle + Array.new(81-9, 0)
  sudoku = Sudoku.new(seed.join)
  sudoku.solve!
  sudoku.to_s.chars
end

def puzzle(sudoku)
  level = session[:level] ||= 10
  sudoku.map { |x| rand(1..level) == level ? "0" : x }
end

def box_order_to_row_order(cells)
  boxes = cells.each_slice(9).to_a
  (0..8).to_a.inject([]) {|memo, i|
    first_box_index = i / 3 * 3
    three_boxes = boxes[first_box_index, 3] 
    three_rows_of_three = three_boxes.map do |box|
      row_number_in_a_box = i % 3
      first_cell_in_the_row_index = row_number_in_a_box * 3
      box[first_cell_in_the_row_index, 3] 
    end
    memo += three_rows_of_three.flatten
  }
end

def generate_new_puzzle_if_necessary
  return if session[:current_solution]
  sudoku = random_sudoku
  session[:solution] = sudoku
  session[:puzzle] = puzzle(sudoku)
  session[:current_solution] = session[:puzzle]
end

def prepare_to_check_solution
  @check_solution = session[:check_solution]
  if @check_solution 
    flash[:notice] = "See those yellow cells? You got those ones wrong ya mug. Just say the word, oh! Su-Su-Susudoku!"
  end
  session[:check_solution] = nil
end

get '/' do
  prepare_to_check_solution
  generate_new_puzzle_if_necessary
  @current_solution = session[:current_solution] || session[:puzzle] 
  @solution = session[:solution]
  @puzzle = session[:puzzle]
  erb :index
end

get '/instructions' do 
  @instructions 
  erb :instructions, :layout => :instructions_layout
end

post '/solution' do
  session[:current_solution] = session[:solution]
  redirect to("/")
end

post '/reset' do
  session[:check_solution] = false
  session[:current_solution] = nil
  flash[:notice] = nil
  redirect to("/")
end

post '/difficulty' do
  session[:current_solution] = nil
  session[:level] = params[:level].to_i
  redirect to("/")
end

post '/' do
  cells = params['cell'] 
  session[:current_solution] = box_order_to_row_order(cells)
  session[:check_solution] = true
  redirect to("/")
end
