collection @questions

attributes id, text, url, topic_id, created_at, updated_at, user_id, status, created_for_asker_id
	
child(:answers) do
  attributes :id, :answer, :correct
end