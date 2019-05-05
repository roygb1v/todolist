require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

# Creates an empty session hash per user; secret key allows server to validate and keep app stateful
configure do
  enable :sessions
  set :session_secret, "secret"
end

# Methods available to view templates and here
helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining_count(list)
    list[:todos].select {|line| !line[:completed]}.size
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_list(lists)
    complete_list, incomplete_list = lists.partition {|list| list_complete?(list)}

    incomplete_list.each {|list| yield(list, lists.index(list))}
    complete_list.each {|list| yield(list, lists.index(list))}
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, index|
      if todo[:completed]
        complete_todos[todo] = index
      else
        incomplete_todos[todo] = index
      end
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

before do
  session[:lists] ||= []
end

# Homepage redirects to lists
get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Edit a single todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb(:edit, layout: :layout)
end

# Edit an existing list
post "/lists/:id" do
  id = params[:id].to_i
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb(:edit, layout: :layout)
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated!"
    redirect "/lists/#{id}"
  end
end

# Render the new list form
get "/lists/new" do
  erb(:new_list, layout: :layout)
end

# Returns an error message if the name is invalid. Returns nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Please enter a field between 1 to 100 characters"
  end
end

# Returns an error message if the name is invalid. Returns nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "Please enter a field between 1 to 100 characters"
  elsif session[:lists].any? {|list| list[:name] == name}
    "This list already exists!"
  end
end

# Create new list. Data entered in /lists/new will be sent to /lists due to action="/lists"
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb(:new_list, layout: :layout)
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created"
    redirect "/lists"
  end
end

# Delete a todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# View a single todo list. Conflicting error here with post /lists/:id but resolved when put after post method
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb(:list, layout: :layout)
end

# Add a new todo item
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_value = params[:todo].strip

  error = error_for_todo(todo_value)
  if error
    session[:error] = error
    erb(:list, layout: :layout)
  else
    session[:lists][@list_id][:todos] << {name: todo_value, completed: false}
    session[:success] = "The todo was a success!"
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:index/destroy" do
  todo_id = params[:list_id].to_i
  index = params[:index].to_i
  session[:lists][todo_id][:todos].delete_at(index)
  session[:success] = "The todo has been successfully deleted!"

  redirect "/lists/#{todo_id}"
end

# Update the status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  index = params[:id].to_i
  is_completed = params[:completed] == "true"

  @list[:todos][index][:completed] = is_completed

  session[:success] = "Your task has been updated!"
  redirect "/lists/#{@list_id}"
end

# Update the status of all todos
post "/list/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  is_completed = params[:completed] == "true"

  @list[:todos].each do |list|
    list[:completed] = is_completed
  end
  session[:success] = "All tasks complete!"
  redirect "/lists/#{@list_id}"
end