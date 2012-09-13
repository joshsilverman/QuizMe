
namespace :questions do
  task :load => :environment do
    require 'csv'
    k = 0
    CSV.foreach("db/questions/govt101.csv") do |row|
      i, question_num, question, url = row
      correct = ''
      incorrect = []
      row[4,16].each do |a|
        next if a.blank?
        if /(.*)\s\(Correct\)$/.match(a)
          correct = a.gsub /\s\(Correct\)$/, ""
        else 
          incorrect << a.gsub(/\s\(Incorrect\)$/, "")
        end
      end
      if question and correct and incorrect.count > 0
        puts "Question #{k}: #{question}"
        # puts "Correct: #{correct}"
        q = Question.where("text like ?", "%#{question}%").first
        if q.blank?
          puts "missed"
          q = Question.create({:text => question, :created_for_asker_id => 2, :user_id => 1, :status => 1, :resource_url => url}) 
          q.answers << Answer.create(:text => correct, :correct => true)
          incorrect.each {|aa| q.answers << Answer.create(:text => aa, :correct => false)}
        else
          puts "updating: #{question}"
          q.update_attributes({:resource_url => url})
        end
      else
        puts "Error!"
        break
      end
      k += 1
    end
  end

  task :import_quizlet_json => :environment do
    cards = JSON.parse('[{"card_id":260,"text":"Who was the 1st U.S. President from 1789-1797?","answer":"George Washington","false_answers":["William H. Harrison","Ronald Reagan","Theodore Roosevelt"]},{"card_id":261,"text":"Who was the 2nd U.S. President from 1979-1801?","answer":"John Adams","false_answers":["Lyndon B. Johnson","John Quincy Adams","Millard Fillmore"]},{"card_id":262,"text":"Who was the 3rd U.S. President from 1801-1809?","answer":"Thomas Jefferson","false_answers":["George H. W. Bush","James Madison","Andrew Johnson"]},{"card_id":264,"text":"Who was the 5th U.S. President from 1817-1825?","answer":"James Monroe","false_answers":["Grover Cleveland","Thomas Jefferson","Rutherford B. Hayes"]},{"card_id":265,"text":"Who was the 6th U.S. President from 1825-1829?","answer":"John Quincy Adams","false_answers":["Ulysses S. Grant","William H. Harrison","Andrew Johnson"]},{"card_id":267,"text":"Who was the 8th U.S. President from 1837-1841?","answer":"Martin Van Buren","false_answers":["Richard Nixon","Chester A. Arthur","Jimmy Carter"]},{"card_id":270,"text":"Who was the 11th U.S. President from 1845-1849?","answer":"James K. Polk","false_answers":["Franklin Pierce","Dwight D. Eisenhower","Chester A. Arthur"]},{"card_id":271,"text":"Who was the 12th U.S. President from 1849-1850 (Died in office of natural causes)?","answer":"Zachary Taylor","false_answers":["Andrew Jackson","Millard Fillmore","George Washington"]},{"card_id":274,"text":"Who was the 15th U.S. President from 1857-1861?","answer":"James Buchanan","false_answers":["Lyndon B. Johnson","George H. W. Bush","Bill Clinton"]},{"card_id":275,"text":"Who was the 16th U.S. President from 1861-1865 (Assassinated)?","answer":"Abraham Lincoln","false_answers":["Dwight D. Eisenhower","James Garfield","James K. Polk"]},{"card_id":276,"text":"Who was the 17th U.S. President from 1865-1869?","answer":"Andrew Johnson","false_answers":["Thomas Jefferson","John Quincy Adams","Ronald Reagan"]},{"card_id":277,"text":"Who was the 18th U.S. President from 1869-1877?","answer":"Ulysses S. Grant","false_answers":["John Quincy Adams","John Adams","William H. Harrison"]},{"card_id":278,"text":"Who was the 19th U.S. President from 1877-1881?","answer":"Rutherford B. Hayes","false_answers":["Ulysses S. Grant","Martin Van Buren","Harry S. Truman"]},{"card_id":279,"text":"Who was the 20th U.S. President from 1881-1881 (Assassinated)?","answer":"James Garfield","false_answers":["Benjamin Harrison","Ronald Reagan","James Monroe"]},{"card_id":280,"text":"Who was the 21st U.S. President from 1881-1885?","answer":"Chester A. Arthur","false_answers":["Millard Fillmore","John Quincy Adams","Ulysses S. Grant"]},{"card_id":266,"text":"Who was the 7th U.S. President from 1829-1837?","answer":"Andrew Jackson","false_answers":["William McKinley","Rutherford B. Hayes","Andrew Johnson"]},{"card_id":268,"text":"Who was the 9th U.S. President from 1841-1841 (Died in office of natural causes)?","answer":"William H. Harrison","false_answers":["Martin Van Buren","Ronald Reagan","George H. W. Bush"]},{"card_id":269,"text":"Who was the 10th U.S. President from 1841-1845?","answer":"John Tyler","false_answers":["James Buchanan","Gerald Ford","Zachary Taylor"]},{"card_id":272,"text":"Who was the 13th U.S. President from 1850-1853?","answer":"Millard Fillmore","false_answers":["Barack Obama","Richard Nixon","George Washington"]},{"card_id":273,"text":"Who was the 14th U.S. President from 1853-1857?","answer":"Franklin Pierce","false_answers":["Lyndon B. Johnson","Millard Fillmore","George Washington"]},{"card_id":281,"text":"Who was the 22nd U.S. President from 1885-1889?","answer":"Grover Cleveland","false_answers":["Chester A. Arthur","James Buchanan","Theodore Roosevelt"]},{"card_id":284,"text":"Who was the 25th U.S. President from 1897-1901 (Assassinated)?","answer":"William McKinley","false_answers":["Richard Nixon","James Monroe","Gerald Ford"]},{"card_id":285,"text":"Who was the 26th U.S. President from 1901-1909?","answer":"Theodore Roosevelt","false_answers":["William H. Taft","James Buchanan","John Quincy Adams"]},{"card_id":286,"text":"Who was the 27th U.S. President from 1909-1913?","answer":"William H. Taft","false_answers":["Theodore Roosevelt","Bill Clinton","Martin Van Buren"]},{"card_id":287,"text":"Who was the 28th U.S. President from 1913-1921?","answer":"Woodrow Wilson","false_answers":["Martin Van Buren","Harry S. Truman","James Garfield"]},{"card_id":263,"text":"Who was the 4th U.S. President from 1809-1817?","answer":"James Madison","false_answers":["Thomas Jefferson","Franklin Pierce","Benjamin Harrison"]},{"card_id":303,"text":"Who was the 44th U.S. President 2009-current?","answer":"Barack Obama","false_answers":["George Washington","James K. Polk","John Adams"]},{"card_id":302,"text":"Who was the 43rd U.S. President from 2001-2009?","answer":"George W. Bush","false_answers":["Theodore Roosevelt","Andrew Jackson","Grover Cleveland"]},{"card_id":301,"text":"Who was the 42nd U.S. President from 1993-2001?","answer":"Bill Clinton","false_answers":["William H. Harrison","Theodore Roosevelt","Chester A. Arthur"]},{"card_id":300,"text":"Who was the 41st U.S. President from 1989-1993?","answer":"George H. W. Bush","false_answers":["William McKinley","Abraham Lincoln","John Adams"]},{"card_id":299,"text":"Who was the 40th U.S. President from 1981-1989?","answer":"Ronald Reagan","false_answers":["Abraham Lincoln","Warren G. Harding","Lyndon B. Johnson"]},{"card_id":298,"text":"Who was the 39th U.S. President from 1977-1981?","answer":"Jimmy Carter","false_answers":["Richard Nixon","Franklin D. Roosevelt","James Garfield"]},{"card_id":297,"text":"Who was the 38th U.S. President from 1974-1977?","answer":"Gerald Ford","false_answers":["Calvin Coolidge","William H. Harrison","James K. Polk"]},{"card_id":296,"text":"Who was the 37th U.S. President from 1969-1974 (Resigned)?","answer":"Richard Nixon","false_answers":["Ulysses S. Grant","Jimmy Carter","Grover Cleveland"]},{"card_id":295,"text":"Who was the 36th U.S. President from 1963-1969?","answer":"Lyndon B. Johnson","false_answers":["George H. W. Bush","Andrew Johnson","Ronald Reagan"]},{"card_id":294,"text":"Who was the 35th U.S. President from 1961-1963 (Assassinated)?","answer":"John F. Kennedy","false_answers":["Woodrow Wilson","Theodore Roosevelt","Zachary Taylor"]},{"card_id":288,"text":"Who was the 29th U.S. President from 1921-1923 (Died of natural causes)?","answer":"Warren G. Harding","false_answers":["Franklin D. Roosevelt","George W. Bush","Millard Fillmore"]},{"card_id":289,"text":"Who was the 30th U.S. President from 1923-1929?","answer":"Calvin Coolidge","false_answers":["Gerald Ford","Martin Van Buren","Ulysses S. Grant"]},{"card_id":290,"text":"Who was the 31st U.S. President from 1929-1933?","answer":"Herbert Hoover","false_answers":["Barack Obama","Franklin D. Roosevelt","Andrew Jackson"]},{"card_id":291,"text":"Who was the 32nd U.S. President from 1933-1945 (Died of natural causes)?","answer":"Franklin D. Roosevelt","false_answers":["John Quincy Adams","Bill Clinton","Grover Cleveland (2nd Term)"]},{"card_id":292,"text":"Who was the 33rd U.S. President from 1945-1953?","answer":"Harry S. Truman","false_answers":["William H. Harrison","Theodore Roosevelt","John Adams"]},{"card_id":293,"text":"Who was the 34th U.S. President from 1953-1961?","answer":"Dwight D. Eisenhower","false_answers":["Jimmy Carter","Lyndon B. Johnson","John Tyler"]},{"card_id":283,"text":"Who was the 24th U.S. President from 1893-1897?","answer":"Grover Cleveland (2nd Term)","false_answers":["Gerald Ford","John Tyler","Franklin D. Roosevelt"]},{"card_id":282,"text":"Who was the 23rd U.S. President from 1889-1893?","answer":"Benjamin Harrison","false_answers":["Lyndon B. Johnson","Harry S. Truman","Ulysses S. Grant"]},{"card_id":304,"text":"Name the president(s) during the War of 1812?","answer":"James Madison","false_answers":["Woodrow Wilson","Abraham Lincoln, Andrew Johnson","James Polk"]},{"card_id":305,"text":"Name the president(s) during the Mexican War (1846-1848)?","answer":"James Polk","false_answers":["none","Woodrow Wilson","Abraham Lincoln, Andrew Johnson"]},{"card_id":307,"text":"Name the president(s) during the Spanish American War (1898)?","answer":"William McKinley","false_answers":["James Polk","Harry Truman, Dwight Eisenhower","Eisenhower, JFK, Lyndon Johnson, Richard Nixon, Gerald Ford"]},{"card_id":306,"text":"Name the president(s) during the Civil War (1861-1865)?","answer":"Abraham Lincoln, Andrew Johnson","false_answers":["Harry Truman, Dwight Eisenhower","Harry Truman to Ronald Regan","Woodrow Wilson"]},{"card_id":308,"text":"Name the president(s) during the Russo-Japanese War (1906)?","answer":"Theodore Roosevelt","false_answers":["Eisenhower, JFK, Lyndon Johnson, Richard Nixon, Gerald Ford","none","Harry Truman to Ronald Regan"]},{"card_id":309,"text":"Name the president(s) during World War I (1914-1918)?","answer":"Woodrow Wilson","false_answers":["Theodore Roosevelt","Abraham Lincoln, Andrew Johnson","Harry Truman, Dwight Eisenhower"]},{"card_id":310,"text":"Name the president(s) during World War II (1939-1945)?","answer":"Franklin Delano Roosevelt, Harrry Truman","false_answers":["William McKinley","Abraham Lincoln, Andrew Johnson","Eisenhower, JFK, Lyndon Johnson, Richard Nixon, Gerald Ford"]},{"card_id":311,"text":"Name the president(s) during the Cold War (1947-1991)?","answer":"Harry Truman to Ronald Regan","false_answers":["James Polk","Abraham Lincoln, Andrew Johnson","none"]},{"card_id":312,"text":"Name the president(s) during the Vietnam War (1954-1975)?","answer":"Eisenhower, JFK, Lyndon Johnson, Richard Nixon, Gerald Ford","false_answers":["James Madison","Woodrow Wilson","Theodore Roosevelt"]},{"card_id":313,"text":"Name the president(s) during the Revolutionary War (1775-1783)?","answer":"none","false_answers":["James Polk","Theodore Roosevelt","Woodrow Wilson"]},{"card_id":314,"text":"Name the president(s) during the Korean War (1950-1953)?","answer":"Harry Truman, Dwight Eisenhower","false_answers":["James Polk","Abraham Lincoln, Andrew Johnson","James Madison"]},{"card_id":315,"text":"The presidential term of ___ was known for being the centennial president.","answer":"Hayes","false_answers":["Cleveland","Cleveland","Cleveland"]},{"card_id":316,"text":"The presidential term of ___ was known for the Sherman Anti-Trust Act.","answer":"Harrison","false_answers":["Arthur","Cleveland","Hayes"]},{"card_id":318,"text":"The presidential term of ___ was known for the Creation of the Federal Civil Service (Pendleton Act).","answer":"Arthur","false_answers":["Cleveland","Cleveland","Hayes"]},{"card_id":323,"text":"The presidential term of ___ was known for the Haymarket Square Incident.","answer":"Cleveland","false_answers":["Cleveland","Arthur","Cleveland"]},{"card_id":324,"text":"The presidential term of ___ was known for the construction of the Brooklyn Bridge.","answer":"Arthur","false_answers":["Hayes","Arthur","Harrison"]},{"card_id":325,"text":"The presidential term of ___ was known for the construction of the Statue of Liberty.","answer":"Cleveland","false_answers":["Arthur","McKinley","Cleveland"]},{"card_id":330,"text":"The presidential term of ___ was known for the Cross of Gold Speech.","answer":"McKinley","false_answers":["Cleveland","Hayes","Cleveland"]},{"card_id":331,"text":"The presidential term of ___ was known for ending Reconstruction.","answer":"Hayes","false_answers":["Harrison","Hayes","McKinley"]},{"card_id":332,"text":"The presidential term of ___ was known for the creation of the ICC.","answer":"Cleveland","false_answers":["Garfield","McKinley","Cleveland"]},{"card_id":333,"text":"The presidential term of ___ was known for the panic of 1893.","answer":"Cleveland","false_answers":["Harrison","Cleveland","Cleveland"]},{"card_id":334,"text":"The presidential term of ___ was known for the Omaha Platform.","answer":"Cleveland","false_answers":["Garfield","Hayes","Grant (two)"]},{"card_id":328,"text":"The presidential term of ___ was known for Munn vs. Illinois.","answer":"Hayes","false_answers":["Hayes","Harrison","Cleveland"]},{"card_id":322,"text":"The presidential term of ___ was known for the creation of the AF of L as an open union.","answer":"Cleveland","false_answers":["Arthur","Hayes","Cleveland"]},{"card_id":335,"text":"The presidential term of ___ was known for the creation of America\'s First Trust (Standard Oil).","answer":"Hayes","false_answers":["Garfield","McKinley","Cleveland"]},{"card_id":336,"text":"The presidential term of ___ was known for being the First Billion Dollar Congress.","answer":"Harrison","false_answers":["Cleveland","Hayes","Hayes"]},{"card_id":321,"text":"The presidential term of ___ was known for the Sherman Silver Purchase.","answer":"Harrison","false_answers":["Arthur","Garfield","Arthur"]},{"card_id":337,"text":"The presidential term of ___ was known for the Mugwumps deciding this election.","answer":"Cleveland","false_answers":["Cleveland","Arthur","Hayes"]},{"card_id":338,"text":"The presidential term of ___ was known for the Bland-Allison Act.","answer":"Hayes","false_answers":["Arthur","Cleveland","Hayes"]},{"card_id":341,"text":"The presidential term of ___ was known for being the first Democratic president following the Civil War.","answer":"Cleveland","false_answers":["Cleveland","Garfield","Cleveland"]},{"card_id":342,"text":"The presidential term of ___ was known for the Pullman Strike.","answer":"Cleveland","false_answers":["Hayes","Hayes","Arthur"]},{"card_id":343,"text":"The presidential term of ___ was known for the All-Steel Navy.","answer":"Arthur","false_answers":["Cleveland","Cleveland","Garfield"]},{"card_id":344,"text":"The presidential term of ___ was known for the Homestead Steel Strike.","answer":"Harrison","false_answers":["Cleveland","Garfield","Cleveland"]},{"card_id":345,"text":"The presidential term of ___ was known for Wabash vs. Illinois.","answer":"Cleveland","false_answers":["Cleveland","McKinley","Harrison"]},{"card_id":329,"text":"The presidential term of ___ was known for Plessy vs. Ferguson.","answer":"Cleveland","false_answers":["Harrison","Grant (two)","Cleveland"]},{"card_id":339,"text":"The presidential term of ___ was known for his refusal to sign Civil War Pensions.","answer":"Cleveland","false_answers":["Arthur","Harrison","Cleveland"]},{"card_id":319,"text":"The presidential term of ___ was known for the McKinley Tariff.","answer":"Harrison","false_answers":["Hayes","McKinley","Cleveland"]},{"card_id":348,"text":"Which US President is best known for the Camp David Accords and Iran Hostage Crisis?","answer":"Jimmy Carter","false_answers":["Ronald Reagan","John F. Kennedy","Franklin D. Roosevelt"]},{"card_id":349,"text":"Which US President is best known for NAFTA, healthcare reform and the Lewinsky scandal?","answer":"Bill Clinton","false_answers":["Ronald Reagan","George W. Bush","Lyndon B. Johnson"]},{"card_id":350,"text":"Which US President is best known for the New Deal?","answer":"Franklin D. Roosevelt","false_answers":["Ronald Reagan","John F. Kennedy","Abraham Lincoln"]},{"card_id":351,"text":"Which US President is best known for being the only person to serve as VP and President without being elected?","answer":"Gerald Ford","false_answers":["Lyndon B. Johnson","Woodrow Wilson","Richard Nixon"]},{"card_id":352,"text":"Which US President is best known for the Cold War ended during his administration?","answer":"George H.W. Bush","false_answers":["Andrew Jackson","George W. Bush","Gerald Ford"]},{"card_id":353,"text":"Which US President is best known for the 9/11 attacks and war on terrorism?","answer":"George W. Bush","false_answers":["Gerald Ford","Harry Truman","Bill Clinton"]},{"card_id":354,"text":"Which US President is best known for the Indian Removal Act?","answer":"Andrew Jackson","false_answers":["Ronald Reagan","Teddy Roosevelt","Bill Clinton"]},{"card_id":355,"text":"Which US President is best known for the New Frontier and Civil Rights?","answer":"John F. Kennedy","false_answers":["George W. Bush","Harry Truman","George H.W. Bush"]},{"card_id":356,"text":"Which US President is best known for the Great Society and the Civil Rights Act?","answer":"Lyndon B. Johnson","false_answers":["George H.W. Bush","Abraham Lincoln","Bill Clinton"]},{"card_id":357,"text":"Which US President is best known for the Emancipation Proclamation and abolishing slavery?","answer":"Abraham Lincoln","false_answers":["John F. Kennedy","Lyndon B. Johnson","Franklin D. Roosevelt"]},{"card_id":358,"text":"Which US President is best known for negotiating with &quot;Communist China&quot; and Watergate?","answer":"Richard Nixon","false_answers":["Franklin D. Roosevelt","Harry Truman","Jimmy Carter"]},{"card_id":359,"text":"Which US President is best known for Reaganomics and huge budget deficits?","answer":"Ronald Reagan","false_answers":["Franklin D. Roosevelt","Bill Clinton","Harry Truman"]},{"card_id":360,"text":"Which US President is best known for the Square Deal and the Roosevelt Corollary?","answer":"Teddy Roosevelt","false_answers":["Bill Clinton","Ronald Reagan","Andrew Jackson"]},{"card_id":361,"text":"Which US President is best known for dropping the atomic bomb on Japan?","answer":"Harry Truman","false_answers":["Gerald Ford","Lyndon B. Johnson","Jimmy Carter"]},{"card_id":362,"text":"Which US President is best known for the proposed League of Nations?","answer":"Woodrow Wilson","false_answers":["Lyndon B. Johnson","George H.W. Bush","George W. Bush"]},{"card_id":539,"text":"Which US President served during the Civil War and abolished slavery?","answer":"Abraham Lincoln","false_answers":["Bill Clinton","George Washington","Thomas Jefferson"]},{"card_id":541,"text":"Which US President lived at Mount Vernon?","answer":"George Washington","false_answers":["John Adams","George W. Bush","Ronald Reagan"]},{"card_id":542,"text":"Which US President has his picture on the quarter and the dollar bill?","answer":"George Washington","false_answers":["Theodore Roosevelt","The White House","Ronald Reagan"]},{"card_id":543,"text":"Which US President wrote the Declaration of Independence?","answer":"Thomas Jefferson","false_answers":["Andrew Jackson","Abraham Lincoln","Abraham Lincoln"]},{"card_id":544,"text":"Which US President was the first vice-president and second president?","answer":"John Adams","false_answers":["Dwight Eisenhower","The White House","Franklin Delano Roosevelt"]},{"card_id":545,"text":"Which US President had the nickname Honest Abe?","answer":"Abraham Lincoln","false_answers":["Thomas Jefferson","Dwight Eisenhower","George W. Bush"]},{"card_id":547,"text":"Which US President lived at Monticello?","answer":"Thomas Jefferson","false_answers":["Theodore Roosevelt","Andrew Jackson","George Washington"]},{"card_id":548,"text":"Which US President is pictured on the $5 bill and the penny?","answer":"Abraham Lincoln","false_answers":["Thomas Jefferson","Dwight Eisenhower","Abraham Lincoln"]},{"card_id":549,"text":"Which US President was the hero of the Battle of New Orleans and the seventh president?","answer":"Andrew Jackson","false_answers":["The White House","Washington DC","Bill Clinton"]},{"card_id":550,"text":"Which US President established Yellowstone, our first national park?","answer":"Theodore Roosevelt","false_answers":["Thomas Jefferson","George Washington","John F. Kennedy"]},{"card_id":551,"text":"Which US President served during the Great Depression and World War II?","answer":"Franklin Delano Roosevelt","false_answers":["Jimmy Carter","John Adams","Thomas Jefferson"]},{"card_id":552,"text":"Which US President was a five star general who was the Supreme Allied Commander in WWII?","answer":"Dwight Eisenhower","false_answers":["George Washington","Thomas Jefferson","Bill Clinton"]},{"card_id":553,"text":"Which US President founded the Peace Corps and was later assassinated in office?","answer":"John F. Kennedy","false_answers":["Ronald Reagan","John Adams","The White House"]},{"card_id":554,"text":"Which US President works with Habitat for Humanity?","answer":"Jimmy Carter","false_answers":["Washington DC","Bill Clinton","Abraham Lincoln"]},{"card_id":555,"text":"Which US President was a Hollywood actor in his younger years?","answer":"Ronald Reagan","false_answers":["John F. Kennedy","Thomas Jefferson","Abraham Lincoln"]},{"card_id":556,"text":"Which US President plays the saxophone?","answer":"Bill Clinton","false_answers":["George W. Bush","Abraham Lincoln","Ronald Reagan"]},{"card_id":557,"text":"Which US President was our 43rd president and had a father who was our 41st president?","answer":"George W. Bush","false_answers":["George Washington","Thomas Jefferson","Abraham Lincoln"]},{"card_id":558,"text":"Which US President was the first African American president?","answer":"Barack Obama","false_answers":["Jimmy Carter","George Washington","Andrew Jackson"]}]')
    asker = User.asker(66)
    return if asker.nil?
    topic_name = "us presidents"

    topic = Topic.find_or_create_by_name(topic_name)

    cards.each do |card|
      q = Question.find_or_create_by_seeder_id(card['card_id'])
      q.update_attributes(
        :text => card['text'],
        :topic_id => topic.id,
        :user_id => 1,
        :status => 1,
        :created_for_asker_id => asker.id
      )
      q.answers.destroy_all unless q.answers.blank?
      q.answers << Answer.create(:text => card['answer'], :correct => true)
      card['false_answers'].each do |fa|
        q.answers << Answer.create(:text => fa, :correct => false)
      end
    end
  end
end

