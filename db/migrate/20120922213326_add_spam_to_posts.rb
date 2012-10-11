class AddSpamToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :spam, :boolean

    # truthset = {10296=>true, 8254=>false, 6323=>false, 239=>false, 7188=>true, 4516=>true, 9290=>true, 11763=>false, 3454=>false, 8484=>true, 10572=>false, 11103=>true, 4868=>false, 8313=>false, 241=>false, 7279=>true, 343=>false, 8763=>true, 3604=>false, 3332=>false, 4201=>false, 1773=>false, 2559=>true, 3512=>false, 2441=>false, 5399=>true, 6311=>false, 3519=>false, 6459=>true, 1033=>false, 984=>false, 6145=>false, 227=>false, 1378=>false, 11374=>false, 6973=>false, 10659=>true, 11044=>true, 4094=>false, 1444=>false, 6426=>false, 10864=>false, 2425=>false, 2605=>true, 7730=>false, 9571=>false, 2903=>true, 9481=>false, 5772=>false, 7922=>false, 5576=>true, 11324=>true, 7142=>true, 958=>false, 8244=>false, 3090=>false, 11701=>false, 1124=>false, 8031=>false, 6496=>true, 10304=>false, 10925=>true, 2244=>true, 8126=>false, 7317=>false, 7315=>false, 4855=>false, 3021=>true, 3162=>false, 5442=>true, 7111=>false, 5955=>false, 8542=>true, 2683=>false, 8300=>false, 5805=>false, 3727=>false, 1102=>false, 9025=>false, 6445=>false, 6584=>true, 2412=>false, 1958=>false, 4590=>true, 10421=>false, 87=>false, 4392=>false, 3818=>false, 2183=>true} 
    # truthset.each do |k,v|
    #   Post.find(k).update_attribute :spam, v
    # end
  end
end
