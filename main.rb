require "openai"
require 'debug'
client = OpenAI::Client.new(access_token: "your-access-token-here")
assistant_response = client.assistants.create(
  parameters: {
    model: "gpt-3.5-turbo-1106",         # Retrieve via client.models.list. Assistants need 'gpt-3.5-turbo-1106' or later.
    name: "OpenAI-Ruby test assistant",
    description: nil,
    instructions: "You are a helpful assistant for coding a OpenAI API client using the OpenAI-Ruby gem.",
    tools: [
      { type: 'retrieval' },           # Allow access to files attached using file_ids
      { type: 'code_interpreter' },    # Allow access to Python code interpreter
    ],
    # "file_ids": ["file-123"],            # See Files section above for how to upload files
    # "metadata": { my_internal_version_id: '1.0.0' }
  })
assistant_id = assistant_response["id"]
puts "Created assistant #{assistant_id}"
#
#
# # Create thread
thread_response = client.threads.create # Note: Once you create a thread, there is no way to list it
# # or recover it currently (as of 2023-12-10). So hold onto the `id`
thread_id = thread_response["id"]
puts "Created thread #{thread_id}"

while true do
  print "> "
  user_inputs = gets.chomp
  if user_inputs == "q"
    break
  end

  client.messages.create(
    thread_id: thread_id,
    parameters: {
      role: "user", # Required for manually created messages
      content: user_inputs
    })
  run_response = client.runs.create(thread_id: thread_id,
                                parameters: {
                                  assistant_id: assistant_id
                                })
  run_id = run_response["id"]
  puts "Created run #{run_id}"
  while true do
    response = client.runs.retrieve(id: run_id, thread_id: thread_id)
    status = response["status"]
    puts "status: #{status}"
    case status
    when "queued", "in_progress", "cancelling"
      puts "Sleeping"
      sleep 1 # Wait one second and poll again
    when "completed"
      break # Exit loop and report result to user
    when "requires_action"
      # Handle tool calls (see below)
    when "cancelled", "failed", "expired"
      puts response["last_error"].inspect
      break # or `exit`
    else
      puts "Unknown status response: #{status}"
    end
  end

  messages = client.messages.list(thread_id: thread_id)
  messages["data"].each do |message|
    # メッセージの履歴が新しい順に入っている
    break if message["role"] == "user"
    puts message.dig("content", 0, "text", "value")
    break
  end
end

client.threads.delete(id: thread_id)
client.assistants.delete(id: assistant_id)
