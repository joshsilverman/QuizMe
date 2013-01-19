class UserMailer < ActionMailer::Base
  default :from => "jsilverman@studyegg.com"
  
  def newsletter(user = nil)
    @user = User.find 11

    drive = GoogleDrive.login("jsilverman@studyegg.com", "GlJnb@n@n@")
    spreadsheet = drive.spreadsheet_by_key("0AliLeS3-noSidGJESjZoZy11bHo2ekNQS2I5TGN6eWc").worksheet_by_title('Sheet1')
    last_row_index = spreadsheet.num_rows - 2
    list = spreadsheet.list

    @jason_text = [list.get(last_row_index, 'Jason Serendipity'), list.get(last_row_index - 1, 'Jason Serendipity')].reject { |t| t.blank? }.first
    @josh_text = [list.get(last_row_index, 'Josh Serendipity'), list.get(last_row_index - 1, 'Josh Serendipity')].reject { |t| t.blank? }.first
    @name = @user.name || @user.twi_name
    @weeks = (Date.today - Date.new(2012,8,20)).to_i/7

    mail(:to => "#{@user.name} <#{@user.email}>", :subject => "Wisr - Recent metrics & experiments")
  end
end
