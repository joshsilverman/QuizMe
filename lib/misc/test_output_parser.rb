logs_text = File.read("test_results.log")

test_groups = logs_text.split(/\n(?=[A-Z][a-z])/)
last_agg_time = nil

test_groups.each do |group|
  tests = group.split("\n")

  tests.each do |test|
    match = test.match(/\s*([A-Z]+)\s+\(([0-9]+)\:00\:([0-9]+\.[0-9]+)\)\s*([a-zA-Z0-9\s_]+)/)
    if match
      o_group = group.split("\n")[0]
      o_test_name = match[4]
      curr_agg_time = match[2].to_f * 60 + match[3].to_f
      o_time = (last_agg_time ? curr_agg_time - last_agg_time : curr_agg_time)
      o_status = match[1]

      last_agg_time = curr_agg_time

      puts "#{o_group}, #{o_test_name}, #{curr_agg_time}, #{o_time}, #{o_status}"
    end
  end
end