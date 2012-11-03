require 'spec_helper'

describe "badges/new" do
  before(:each) do
    assign(:badge, stub_model(Badge,
      :asker_id => 1,
      :title => "MyString",
      :filename => "MyString",
      :description => "MyText"
    ).as_new_record)
  end

  it "renders new badge form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => badges_path, :method => "post" do
      assert_select "input#badge_asker_id", :name => "badge[asker_id]"
      assert_select "input#badge_title", :name => "badge[title]"
      assert_select "input#badge_filename", :name => "badge[filename]"
      assert_select "textarea#badge_description", :name => "badge[description]"
    end
  end
end
