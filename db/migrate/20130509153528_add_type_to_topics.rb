class AddTypeToTopics < ActiveRecord::Migration
  def up
    add_column :topics, :type_id, :integer
    Topic.all.each { |t| t.destroy unless t.askers.present? }
    Topic.where("type_id is null").each { |t| t.update_attribute :type_id, 1 }
    ACCOUNT_DATA.each do |asker_id, data|
      next if Asker.where(id: asker_id).empty?

    	if data[:hashtags]
	    	data[:hashtags].each do |name|
	    		Asker.find(asker_id).topics << Topic.find_or_create_by_name_and_type_id(name, 2) 
	    	end
	    end
    	if data[:search_terms]
	    	data[:search_terms].each do |name|
	    		Asker.find(asker_id).topics << Topic.find_or_create_by_name_and_type_id(name, 3) 
	    	end
    	end
    	if data[:category]
	    	Asker.find(asker_id).topics << Topic.find_or_create_by_name_and_type_id(data[:category], 4)  
	    end
    end
  end

  def down 
  	Topic.where("type_id != 1").destroy_all
  	remove_column :topics, :type_id
  end
end
