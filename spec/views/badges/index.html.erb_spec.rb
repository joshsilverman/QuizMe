require 'spec_helper'

describe "badges/index" do
  before(:each) do
    assign(:badges, [
      stub_model(Badge,
        :asker_id => 1,
        :title => "Title",
        :filename => "Filename",
        :description => "MyText"
      ),
      stub_model(Badge,
        :asker_id => 1,
        :title => "Title",
        :filename => "Filename",
        :description => "MyText"
      )
    ])
  end

  it "renders a list of badges" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Title".to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Filename".to_s, :count => 2
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
  end
end
