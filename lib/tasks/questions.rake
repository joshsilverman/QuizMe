require 'net/http'
require 'uri'

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
    cards = JSON.parse('[{"card_id":1355,"text":"Which field involves the study of behavior and thinking using the experimental method?","answer":"experimental psychology","false_answers":["psychometrics","educational psychology","psychodynamic psychology"]},{"card_id":1357,"text":"Which field involves the study of the potential for growth of healthy people (Maslow, Rogers)?","answer":"humanistic psychology","false_answers":["educational psychology","cognitive neuroscience","basic research"]},{"card_id":1358,"text":"Which field involves the interdisciplinary study of the brain activity linked with cognition?","answer":"cognitive neuroscience","false_answers":["behavioral psychology","psychodynamic psychology","biological psychology"]},{"card_id":1359,"text":"Which field involves the science of behavior and mental processes?","answer":"psychology","false_answers":["developmental psychology","behavioral psychology","human factors psychology"]},{"card_id":1364,"text":"Which field involves the study of links between biological and psychological processes?","answer":"biological psychology","false_answers":["human factors psychology","cognitive psychology","experimental psychology"]},{"card_id":1365,"text":"Which field involves the study of the roots of behavior using the principles of natural selection?","answer":"evolutionary psychology","false_answers":["psychodynamic psychology","counseling psychology","behavioral psychology"]},{"card_id":1366,"text":"Which field involves the study of how unconscious drives/conflicts influence behavior?","answer":"psychodynamic psychology","false_answers":["industrial-organizational (I/O) psychology","social-cultural psychology","educational psychology"]},{"card_id":1367,"text":"Which field involves the study of observable behavior, and its explanation by principles of learning?","answer":"behavioral psychology","false_answers":["evolutionary psychology","industrial-organizational (I/O) psychology","developmental psychology"]},{"card_id":1368,"text":"Which field involves the study of mental activities associated with thinking/knowing/remembering/communicating?","answer":"cognitive psychology","false_answers":["human factors psychology","educational psychology","counseling psychology"]},{"card_id":1369,"text":"Which field involves the study of how situations and cultures affect our behavior/thinking?","answer":"social-cultural psychology","false_answers":["experimental psychology","applied research","educational psychology"]},{"card_id":1370,"text":"Which field involves the study of the measurement of human abilities/attitudes/traits?","answer":"psychometrics","false_answers":["personality psychology","cognitive psychology","cognitive neuroscience"]},{"card_id":1372,"text":"Which field involves the study of physical, cognitive, and social change throughout the lifespan?","answer":"developmental psychology","false_answers":["humanistic psychology","personality psychology","social-cultural psychology"]},{"card_id":1373,"text":"Which field involves the study of how psychological processes affect teaching and learning?","answer":"educational psychology","false_answers":["social psychology","developmental psychology","behavioral psychology"]},{"card_id":1374,"text":"Which field involves the study of an individual\'s characteristic pattern of thinking, feeling and acting?","answer":"personality psychology","false_answers":["humanistic psychology","developmental psychology","social-cultural psychology"]},{"card_id":1375,"text":"Which field involves the study of how we think about, influence, and relate to one another?","answer":"social psychology","false_answers":["evolutionary psychology","psychology","behavioral psychology"]},{"card_id":1378,"text":"Which field involves the study of how people and machines interact?","answer":"human factors psychology","false_answers":["psychology","applied research","social-cultural psychology"]},{"card_id":1379,"text":"Which field involves a branch of psychology that assists people in achieving greater work/life/marriage well-being?","answer":"counseling psychology","false_answers":["clinical psychology","evolutionary psychology","developmental psychology"]},{"card_id":1380,"text":"Which field involves a branch of psychology that studies, assesses, and treats people with psychological disorders?","answer":"clinical psychology","false_answers":["counseling psychology","social-cultural psychology","personality psychology"]},{"card_id":1381,"text":"Which field involves a branch of medicine dealing with psychological disorders?","answer":"psychiatry","false_answers":["social-cultural psychology","psychology","psychometrics"]},{"card_id":1377,"text":"Which field involves the application of psychological concepts and methods to optimizing human behavior in workplaces?","answer":"industrial-organizational (I/O) psychology","false_answers":["applied research","humanistic psychology","clinical psychology"]},{"card_id":1352,"text":"Which school of thought held that knowledge originates in experience and science should rely on observation and experimentation?","answer":"empiricism","false_answers":["structuralism","behaviorism","functionalism"]},{"card_id":1353,"text":"Which school of thought held that introspection could be used to explore the structural elements of the human mind?","answer":"structuralism","false_answers":["functionalism","behaviorism","empiricism"]},{"card_id":1354,"text":"Which school of thought held that mental states (beliefs, desires, being in pain, etc.) are constituted solely by their functional role?","answer":"functionalism","false_answers":["empiricism","structuralism","behaviorism"]},{"card_id":1356,"text":"Which school of thought held that psychology should be objective and therefore revolve around the study of behavior?","answer":"behaviorism","false_answers":["structuralism","empiricism","functionalism"]},{"card_id":1382,"text":"Who of the following is most associated with evolution and natural selection?","answer":"Charles Darwin","false_answers":["B.F. Skinner","William James","Wilhelm Wundt"]},{"card_id":1383,"text":"Who of the following is most associated with behaviorism, reinforcement and operant conditioning?","answer":"B.F. Skinner","false_answers":["Margarent Washburn","Ivan Pavlov","Mary Whiton Calkins"]},{"card_id":1384,"text":"Who of the following is most associated with behaviorism and &quot;Little Albert&quot;?","answer":"John Watson & Rosalie Rayner","false_answers":["Carl Rogers & Abraham Maslow","Edward Titchener","Mary Whiton Calkins"]},{"card_id":1385,"text":"Who of the following is most associated with psychoanalysis, psychodynamics and the unconscious?","answer":"Sigmund Freud","false_answers":["John Watson & Rosalie Rayner","Mary Whiton Calkins","Charles Darwin"]},{"card_id":1388,"text":"Who of the following is most associated with factionalism and the 1st psychology textbook?","answer":"William James","false_answers":["Ivan Pavlov","B.F. Skinner","John Watson & Rosalie Rayner"]},{"card_id":1389,"text":"Who of the following is most associated with the 1st psychology lab and structuralism?","answer":"Wilhelm Wundt","false_answers":["Charles Darwin","Carl Rogers & Abraham Maslow","Ivan Pavlov"]},{"card_id":1390,"text":"Who of the following is most associated with structuralism and introspection?","answer":"Edward Titchener","false_answers":["Carl Rogers & Abraham Maslow","Charles Darwin","John Watson & Rosalie Rayner"]},{"card_id":1391,"text":"Who of the following is most associated with behaviorism, conditioning and Russian Psychology?","answer":"Ivan Pavlov","false_answers":["Sigmund Freud","Edward Titchener","B.F. Skinner"]},{"card_id":1392,"text":"Who of the following is most associated with humanism?","answer":"Carl Rogers & Abraham Maslow","false_answers":["Wilhelm Wundt","B.F. Skinner","William James"]},{"card_id":1396,"text":"The experimental factor that is manipulated and whose effect is being studied is called the ____.","answer":"independent variable","false_answers":["dependent variables"]},{"card_id":1397,"text":"The The outcome factor may change in response to manipulations of other factors is called the ____.","answer":"dependent variables","false_answers":["independent variable"]},{"card_id":1398,"text":"The most frequently occurring value in a distribution is called the ___.","answer":"mode","false_answers":["median","standard deviation","mean"]},{"card_id":1399,"text":"The arithmetic average of a distribution is called the ___.","answer":"mean","false_answers":["standard deviation","mode","median"]},{"card_id":1400,"text":"The middle value in a distribution (half the values are above and half below) is called the ___.","answer":"median","false_answers":["standard deviation","mean","mode"]},{"card_id":1425,"text":"The difference between the highest and lowest scores in a distribution is called the ___.","answer":"range","false_answers":["mode","median","mean"]},{"card_id":1401,"text":"A computed measure of how much scores vary around the mean score is called the ___.","answer":"standard deviation","false_answers":["range","mean","median"]},{"card_id":1422,"text":"In an experiment, the group that is exposed to the treatment is called ___.","answer":"experimental group","false_answers":["control group"]},{"card_id":1423,"text":"In an experiment, the group that is not exposed to the treatment is called ___.","answer":"control group","false_answers":["experimental group"]},{"card_id":1431,"text":"Who was/were the psychologist(s) who used dolls to study children\'s attitude towards race?","answer":"Kenneth and Mamie Clark","false_answers":["Amos Tversky","James Randi","Daniel Kahneman"]},{"card_id":1432,"text":"Who was/were the psychologist(s) known for research on judgment, decision-making, behavioral econ, etc.?","answer":"Daniel Kahneman","false_answers":["Amos Tversky","James Randi","Kenneth and Mamie Clark"]},{"card_id":1434,"text":"Who was/were the key figure(s) in the discovery of systematic human cognitive bias?","answer":"Amos Tversky","false_answers":["Daniel Kahneman","Kenneth and Mamie Clark","James Randi"]},{"card_id":1402,"text":"In statistics, assigning participants to experimental and control conditions by chance is called ___.","answer":"random assignment","false_answers":["sample","confounding variable","operational definition"]},{"card_id":1403,"text":"In statistics, a random selection of members where each has an equal chance of inclusion is called ___.","answer":"random sampling","false_answers":["correlation coefficient","statistical significance","sample"]},{"card_id":1409,"text":"In statistics, a measure of how much two factors vary together is called ___.","answer":"correlation","false_answers":["normal curve/distribution","operational definition","correlation coefficient"]},{"card_id":1412,"text":"In statistics, a statement of how likely it is that an obtained result occurred by chance is called ___.","answer":"statistical significance","false_answers":["random sampling","correlation coefficient","normal curve/distribution"]},{"card_id":1413,"text":"In statistics, a statement of the procedures used to define research variables is called ___.","answer":"operational definition","false_answers":["random sampling","confounding variable","sample"]},{"card_id":1417,"text":"In statistics, the group from which samples are drawn is called ___.","answer":"population","false_answers":["normal curve/distribution","confounding variable","random assignment"]},{"card_id":1418,"text":"In statistics, the group of items selected from a population is called ___.","answer":"sample","false_answers":["normal curve/distribution","random assignment","correlation coefficient"]},{"card_id":1419,"text":"In statistics, the index of the relationship between two things (from -1 to +1) is called ___.","answer":"correlation coefficient","false_answers":["population","confounding variable","operational definition"]},{"card_id":1424,"text":"In statistics, a factor other than the independent variable that effects the experiment is called ___.","answer":"confounding variable","false_answers":["correlation","correlation coefficient","sample"]},{"card_id":1426,"text":"In statistics, a symmetrical, bell-shaped curve where most scores fall near the mean is called ___.","answer":"normal curve/distribution","false_answers":["operational definition","statistical significance","correlation coefficient"]},{"card_id":1406,"text":"Which method of inquiry involves studying one person in depth in the hope of revealing universal principles?","answer":"case study","false_answers":["experiment","survey","naturalistic observation"]},{"card_id":1407,"text":"Which method of inquiry involves ascertaining self-reported attitudes or behaviors of people with representative questioning?","answer":"survey","false_answers":["experiment","case study","naturalistic observation"]},{"card_id":1408,"text":"Which method of inquiry involves observing/recording behavior in naturally occurring situations?","answer":"naturalistic observation","false_answers":["experiment","survey","case study"]},{"card_id":1410,"text":"Which method of inquiry involves manipulation of independent variables to observe effects on behavior/mental process?","answer":"experiment","false_answers":["naturalistic observation","survey","case study"]},{"card_id":1415,"text":"In empirical research, an explanation that organizes and predicts observations is call a ___.","answer":"theory","false_answers":["hypothesis"]},{"card_id":1416,"text":"In empirical research, a testable prediction, often implied by a theory is call a ___.","answer":"hypothesis","false_answers":["theory"]},{"card_id":1458,"text":"Which neuron carries information from the sensory receptors to the brain and spinal cord?","answer":"sensory","false_answers":["motor","interneuron"]},{"card_id":1459,"text":"Which neuron carries outgoing information from the brain and spinal cord to the muscles and glands?","answer":"motor","false_answers":["interneuron","sensory"]},{"card_id":1460,"text":"Which neuron communicates internally and intervenes between the input and output neurons?","answer":"interneuron","false_answers":["motor","sensory"]},{"card_id":1437,"text":"Which chemical type mimics the action of a neurotransmitter?","answer":"agonist","false_answers":["antagonist"]},{"card_id":1438,"text":"Which chemical type opposes the action of a neurotransmitter?","answer":"antagonist","false_answers":["agonist"]},{"card_id":1439,"text":"The ___ system controls to the heart, blood vessels, smooth muscles, and glands.","answer":"autonomic nervous","false_answers":["somatic nervous","endocrine","central nervous"]},{"card_id":1441,"text":"The ___ system includes the brain and the spinal cord.","answer":"central nervous","false_answers":["autonomic nervous","peripheral nervous","somatic nervous"]},{"card_id":1451,"text":"The ___ system consists of nerves that lie outside the brain and spinal cord.","answer":"peripheral nervous","false_answers":["autonomic nervous","somatic nervous","central nervous"]},{"card_id":1455,"text":"The ___ system connects to voluntary skeletal muscles and to sensory receptors.","answer":"somatic nervous","false_answers":["peripheral nervous","central nervous","autonomic nervous"]},{"card_id":1445,"text":"The ___ system consists of glands/chemicals that regulate body functions.","answer":"endocrine","false_answers":["central nervous","somatic nervous","peripheral nervous"]},{"card_id":1440,"text":"Which neuron part is a long, thin fiber that sends signals away from the neuron to other neurons/muscles/glands?","answer":"axon","false_answers":["myelin sheath","dendrites","synapse"]},{"card_id":1443,"text":"Which neuron part is a group of branchlike parts specialized to receive information?","answer":"dendrites","false_answers":["synapse","myelin sheath","axon"]},{"card_id":1457,"text":"Which neuron part is a junction where information is transmitted from one neuron to the next?","answer":"synapse","false_answers":["axon","dendrites","myelin sheath"]},{"card_id":1461,"text":"Which neuron part is a layer of fatty tissue encasing the fibers and enabling greater transmission speed?","answer":"myelin sheath","false_answers":["synapse","dendrites","axon"]},{"card_id":1444,"text":"Axons that carry information outward from the CNS to the periphery are called ___.","answer":"efferent nerve fibers","false_answers":["neurotransmitters","hormones","nerves"]},{"card_id":1447,"text":"Bundles of axons that are routed together in the peripheral nervous system are called ___.","answer":"nerves","false_answers":["efferent nerve fibers","neurotransmitters","hormones"]},{"card_id":1448,"text":"Individual cells in the nervous system that receive/integrate/transmit information are called ___.","answer":"neurons","false_answers":["efferent nerve fibers","hormones","neurotransmitters"]},{"card_id":1449,"text":"Chemicals that transmit information from one neuron to another are called ___.","answer":"neurotransmitters","false_answers":["nerves","neurons","efferent nerve fibers"]},{"card_id":1446,"text":"The chemical substances released by the endocrine glands are called ___.","answer":"hormones","false_answers":["nerves","neurons","efferent nerve fibers"]},{"card_id":1452,"text":"Which gland is the &quot;master gland&quot; of the endocrine system releasing a variety of hormone?","answer":"pituitary","false_answers":["adrenal"]},{"card_id":1462,"text":"Which gland is is it that sits above the kidneys secreting arousal hormones in times of stress?","answer":"adrenal","false_answers":["pituitary"]},{"card_id":1450,"text":"Which part of the ANS conserves bodily resources?","answer":"parasympathetic","false_answers":["sympathetic"]},{"card_id":1456,"text":"Which part of the ANS mobilizes the body\'s resources for emergencies?","answer":"sympathetic","false_answers":["parasympathetic"]},{"card_id":1436,"text":"The brief change in a neuron\'s electrical charge is ___.","answer":"action potential","false_answers":["resting potential"]},{"card_id":1453,"text":"The stable, negative charge of a neuron when it is inactive is ___.","answer":"resting potential","false_answers":["action potential"]},{"card_id":1464,"text":"Which brain measurement method shows the waves of the brain\'s electrical activity with electrodes placed on scalp?","answer":"electroencephalogram (EEG)","false_answers":["MRI (magnetic resonance imaging)","CT (computed tomography) scan","(PET) Positron emission tomography scan"]},{"card_id":1465,"text":"Which brain measurement method takes a series of x-ray photographs and combines them into a composite representaion?","answer":"CT (computed tomography) scan","false_answers":["MRI (magnetic resonance imaging)","electroencephalogram (EEG)","fMRI (functional MRI)"]},{"card_id":1466,"text":"Which brain measurement method detects where a radioactive form of glucose goes while the brain performs a task?","answer":"(PET) Positron emission tomography scan","false_answers":["CT (computed tomography) scan","electroencephalogram (EEG)","MRI (magnetic resonance imaging)"]},{"card_id":1467,"text":"Which brain measurement method uses magnetic fields and radio waves to map still brain structures?","answer":"MRI (magnetic resonance imaging)","false_answers":["electroencephalogram (EEG)","fMRI (functional MRI)","CT (computed tomography) scan"]},{"card_id":1502,"text":"Which brain measurement method reveals bloodflow and brain activity by comparing successive MRI scans?","answer":"fMRI (functional MRI)","false_answers":["MRI (magnetic resonance imaging)","electroencephalogram (EEG)","(PET) Positron emission tomography scan"]},{"card_id":1468,"text":"Which brain/area part is the oldest part and central core of brain?","answer":"brainstem","false_answers":["sensory cortex","cerebellum","temporal lobes"]},{"card_id":1469,"text":"Which brain/area part is the base of the brainstem (responsible for breathing, circulation)?","answer":"medualla","false_answers":["temporal lobes","hypothalamous","Broca\'s area"]},{"card_id":1471,"text":"Which brain/area part is part of the brainstem and important for sleep/arousal?","answer":"pons","false_answers":["Broca\'s area","association areas","sensory cortex"]},{"card_id":1472,"text":"Which brain/area part is the brains \'sensory switch board\' located at top of brainstem?","answer":"thalamus","false_answers":["occipital lobes","motor cortex","amygdala"]},{"card_id":1473,"text":"Which brain/area part is the &quot;little brain&quot; in charge of muscle movement, balance, and coordination?","answer":"cerebellum","false_answers":["parietal lobes","brainstem","amygdala"]},{"card_id":1474,"text":"Which brain/area part is a system of brain structures at the border of the brainstem associated with emotions?","answer":"limbic system","false_answers":["parietal lobes","thalamus","amygdala"]},{"card_id":1475,"text":"Which brain/area part is a group of neural clusters, part of the limbic system and are linked to emotion?","answer":"amygdala","false_answers":["association areas","brainstem","corpus callosum"]},{"card_id":1476,"text":"Which brain/area part is a neural structure below the thalamus (directs eating, drinking, body temperature)?","answer":"hypothalamous","false_answers":["Wernicke\'s area","cerebral cortex","parietal lobes"]},{"card_id":1477,"text":"Which brain/area part is the part of the limbic system that processes memory?","answer":"hippocampus","false_answers":["hypothalamous","association areas","Wernicke\'s area"]},{"card_id":1478,"text":"Which brain/area part is the sheet interconnected neurons used in higher order thinking?","answer":"cerebral cortex","false_answers":["occipital lobes","Broca\'s area","hypothalamous"]},{"card_id":1480,"text":"Which brain/area part is the part of the cortex behind the forehead involved in speaking/movement/judgement?","answer":"frontal lobes","false_answers":["Broca\'s area","medualla","Wernicke\'s area"]},{"card_id":1481,"text":"Which brain/area part is the part of the cortex at the top of the head with the sensory cortex?","answer":"parietal lobes","false_answers":["limbic system","hypothalamous","amygdala"]},{"card_id":1482,"text":"Which brain/area part is the part of the cortex at the back of the head with the visual areas?","answer":"occipital lobes","false_answers":["frontal lobes","pons","medualla"]},{"card_id":1483,"text":"Which brain/area part is the part of the cortex above the ears with the auditory areas?","answer":"temporal lobes","false_answers":["Broca\'s area","sensory cortex","motor cortex"]},{"card_id":1484,"text":"Which brain/area part is an area at the rear of the frontal lobes that controls voluntary movement?","answer":"motor cortex","false_answers":["limbic system","temporal lobes","frontal lobes"]},{"card_id":1486,"text":"Which brain/area part is the area at the front of the parietal lobes that registers and processes sensation?","answer":"sensory cortex","false_answers":["brainstem","corpus callosum","occipital lobes"]},{"card_id":1488,"text":"Which brain/area part is in control of speech?","answer":"Broca\'s area","false_answers":["limbic system","cerebellum","motor cortex"]},{"card_id":1489,"text":"Which brain/area part is in control of language reception?","answer":"Wernicke\'s area","false_answers":["cerebral cortex","hypothalamous","cerebellum"]},{"card_id":1492,"text":"Which brain/area part is used to share info back and forth between brain hemispheres?","answer":"corpus callosum","false_answers":["motor cortex","thalamus","amygdala"]},{"card_id":1497,"text":"Which scientist discovered the area in the brain responsible for speech?","answer":"Paul Broca","false_answers":["Roger Sperry","Karl Wernicke","Michael Gazzaniga"]},{"card_id":1499,"text":"Which scientist studied the neural basis of the mind and initiated split-brain research?","answer":"Michael Gazzaniga","false_answers":["Paul Broca","Roger Sperry","Karl Wernicke"]},{"card_id":1500,"text":"Which scientist won a Nobel Prize for work with split brain patients?","answer":"Roger Sperry","false_answers":["Paul Broca","Karl Wernicke","Michael Gazzaniga"]},{"card_id":1501,"text":"Which scientist discovered the area of left temporal lobe involved in language reception?","answer":"Karl Wernicke","false_answers":["Michael Gazzaniga","Roger Sperry","Paul Broca"]},{"card_id":1487,"text":"Which disorder impairs language ability?","answer":"aphasia","false_answers":["split brain"]},{"card_id":1493,"text":"Which disorder is characterized by no communication between brain hemispheres?","answer":"split brain","false_answers":["aphasia"]}]')
    asker = User.asker(108)
    return if asker.nil?
    topic_name = "psychology"

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

  task :seeder_import, [:seeder_id, :asker_id, :topic_name] => :environment do |t, args|
    #get asker account
    asker = User.asker(args[:asker_id])
    if asker.nil?
      puts 'No Asker Found!'
      return
    end

    #get topic
    topic = Topic.find_or_create_by_name(args[:topic_name].downcase)

    #get cards from seeder
    url = URI.parse("http://seeder.herokuapp.com/handles/#{args[:seeder_id]}/export.json")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    begin
      cards = JSON.parse(res.body)
    rescue
      cards=[]
    end

    total = cards.count      
    cards.each_with_index do |card, i|
      #puts "#{card['text']} => #{card['answer']}"
      q = Question.find_or_create_by_seeder_id(card['card_id'])
      unless q.text == card['text'] &&
              q.topic_id == topic.id &&
              q.created_for_asker_id == asker.id
        q.update_attributes(:text => card['text'],
                            :topic_id => topic.id,
                            :user_id => 1,
                            :status => 1,
                            :created_for_asker_id => asker.id)
        q.answers.destroy_all unless q.answers.blank?
        q.answers << Answer.create(:text => card['answer'], :correct => true)
        card['false_answers'].each do |fa|
          q.answers << Answer.create(:text => fa, :correct => false)
        end
      end

      #compute and show progress
      complete = ((i / total.to_f)*100).to_i
      pbar = ''
      space = ''
      for num in 0..(complete/2) do
        pbar += '=' if num > 0
      end

      for num in 0..(50-pbar.length) do
        space+=' '
      end
      puts "[#{pbar}#{space}] #{complete}%"
    end

    puts "[==================================================] 100%"
  end


  task :qb_import, [:qb_book_id, :asker_id, :topic_name] => :environment do |t, args|
    puts "start with args:"
    puts "qb_book_id => #{args[:qb_book_id]}"
    puts "asker_id => #{args[:asker_id]}"
    puts "topic_name => #{args[:topic_name]}"
    #get asker account
    asker = User.asker(args[:asker_id])
    if asker.nil?
      puts 'No Asker Found!'
      return
    end

    #get topic
    topic = Topic.find_or_create_by_name(args[:topic_name].downcase)

    #get cards from seeder
    url = URI.parse("http://questionbase.studyegg.com/api-V1/JKD673890RTSDFG45FGHJSUY/get_book_details/#{args[:qb_book_id]}.json")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    begin
      ch = JSON.parse(res.body)
    rescue
      ch=[]
    end

    questions = []
    ch['chapters'].each do |chapter|
      puts chapter['id']
      url = URI.parse("http://questionbase.studyegg.com/api-V1/JKD673890RTSDFG45FGHJSUY/get_all_lesson_questions/#{chapter['id']}.json")
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      begin
        qs = JSON.parse(res.body)
      rescue
        qs=[]
      end

      questions += qs['questions']
    end

    total = questions.count
    questions.each_with_index do |q, i|
      question_text = q['question']
      wisr_question = nil
      if question_text.downcase=~ /true\sor\sfalse|true\/false|t\/f/
        begin
          question_chunk = question_text[(question_text.downcase=~ /:/)..-1]
          wisr_question = Question.where("text like ?", "%#{question_chunk}%").first
          if wisr_question.nil?
            wisr_question = Question.find_or_create_by_text("T\\F#{question_chunk}")
          end
        rescue
          puts "ERROR!"
          puts "chunk: #{question_chunk}"
          puts wisr_question.inspect
        end
      else
        wisr_question = Question.find_or_create_by_text(q['question'])
      end
      resources = q['resources'] || []
      resource_url = nil
      resources.each do |r|
        next unless wisr_question.resource_url.blank? and r['media_type'] == "video"
        resource_url = "http://www.youtube.com/watch?v=#{r['url']}&t=#{r['begin']}"
        puts resource_url
      end
      wisr_question.update_attributes(:topic_id => topic.id,
                            :user_id => 1,
                            :status => 1,
                            :created_for_asker_id => asker.id,
                            :resource_url => resource_url)
      wisr_question.answers.destroy_all
      q['answers'].each do |a|
        ans = a['answer']
        ans = a['answer'].capitalize if a['answer'].downcase=~/true|false/
        wisr_question.answers << Answer.create(:text => ans, :correct => a['correct'])
      end

      #compute and show progress
      complete = ((i / total.to_f)*100).to_i
      pbar = ''
      space = ''
      for num in 0..(complete/2) do
        pbar += '=' if num > 0
      end

      for num in 0..(50-pbar.length) do
        space+=' '
      end
      puts "[#{pbar}#{space}] #{complete}%"
    end

    puts "[==================================================] 100%"

      #puts "#{card['text']} => #{card['answer']}"
      # q = Question.find_or_create_by_seeder_id(card['card_id'])
      # unless q.text == card['text'] &&
      #         q.topic_id == topic.id &&
      #         q.created_for_asker_id == asker.id
      #   q.update_attributes(:text => card['text'],
      #                       :topic_id => topic.id,
      #                       :user_id => 1,
      #                       :status => 1,
      #                       :created_for_asker_id => asker.id)
      #   q.answers.destroy_all unless q.answers.blank?
      #   q.answers << Answer.create(:text => card['answer'], :correct => true)
      #   card['false_answers'].each do |fa|
      #     q.answers << Answer.create(:text => fa, :correct => false)
      #   end
      # end

  end
end