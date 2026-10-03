#!/usr/bin/env ruby
require "json"
require "pathname"
require "vips"

baseline, candidate = ARGV.map { |path| Pathname.new(path) }
abort "Usage: ruby script/verify_ui_parity.rb BASELINE_DIRECTORY CANDIDATE_DIRECTORY" unless baseline&.directory? && candidate&.directory?

results = baseline.glob("*.json").reject { |path| path.basename.to_s == "comparison.json" }.map do |reference|
  name = reference.basename.to_s
  actual = candidate.join(name)
  next { page: name, error: "Missing candidate capture" } unless actual.file?

  before_metrics = JSON.parse(reference.read)
  after_metrics = JSON.parse(actual.read)
  before = Vips::Image.new_from_file(reference.sub_ext(".png").to_s)
  after = Vips::Image.new_from_file(actual.sub_ext(".png").to_s)
  same_size = [ before.width, before.height ] == [ after.width, after.height ]
  result = { page: reference.basename(".json").to_s, metrics_equal: before_metrics == after_metrics, same_size: same_size }
  if same_size
    diff = (before - after).abs
    changed = (diff > 2).bandor
    result[:max_channel_difference] = diff.max
    result[:changed_pixels] = (changed.avg / 255 * before.width * before.height).round
    result[:changed_ratio] = result[:changed_pixels].fdiv(before.width * before.height)
    diff.write_to_file(candidate.join("#{reference.basename('.json')}-diff.png").to_s) if result[:changed_pixels].positive?
  end
  result
end
abort "No baseline captures found" if results.empty?
File.write(candidate.join("comparison.json"), JSON.pretty_generate(results))
failures = results.select { |result| result[:error] || !result[:metrics_equal] || !result[:same_size] || result[:changed_ratio].to_f > 0.001 || result[:max_channel_difference].to_f > 16 }
puts "#{results.size - failures.size}/#{results.size} captures pass: exact component measurements; pixel tolerance ≤2 per channel, ≤0.1% pixels above that, max deviation 16."
failures.each { |result| puts JSON.generate(result) }
exit(failures.empty? ? 0 : 1)
