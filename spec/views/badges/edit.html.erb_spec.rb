require 'spec_helper'

describe "badges/edit" do
  before(:each) do
    @badge = assign(:badge, stub_model(Badge,
      :asker_id => 1,
      :title => "MyString",
      :filename => "MyString",
      :description => "MyText"
    ))
  end

  it "renders the edit badge form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => badges_path(@badge), :method => "post" do
      assert_select "input#badge_asker_id", :name => "badge[asker_id]"
      assert_select "input#badge_title", :name => "badge[title]"
      assert_select "input#badge_filename", :name => "badge[filename]"
      assert_select "textarea#badge_description", :name => "badge[description]"
    end
  end
end
