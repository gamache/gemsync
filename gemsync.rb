#!/usr/bin/ruby
# Small script to sync multiple gem installations.
# ©2010 Josh Ellithorpe

require 'rubygems'
require 'trollop'

# Setup arguments from the command line.
opts = Trollop::options do
  version "gemsync 0.1.0 (c) 2010 Josh Ellithorpe"
  banner <<-EOS
Small script to sync multiple gem installations.

Usage: gemsync [options]

Available Options:
EOS
  opt :source, "Either the ruby installation directory, or a list of gems produced from 'gem list'. Ex: /usr or /path/to/gemlist.txt", :type => String, :required => true
  opt :destination, "Ruby installation directory you want to sync up. Ex: /opt/ruby-enterprise", :type => String, :required => true
  opt :build_docs, "Build documentation", :default => false
end

source_type = 'file'

# If source is not just a text file, or the text file specified doesn't exist
unless File.readable?(opts[:source])
  source_type = 'directory'
  Trollop::die :source, "\n\t-- Directory or file '#{opts[:source]}' does not exist" unless File.directory?(opts[:source])
  Trollop::die :source, "\n\t-- Binary '#{opts[:source]}/bin/gem' does not exist" unless File.exists?("#{opts[:source]}/bin/gem")
end

Trollop::die :destination, "\n\t-- Directory '#{opts[:destination]}' does not exist" unless File.directory?(opts[:destination])
Trollop::die :destination, "\n\t-- Binary '#{opts[:destination]}/bin/gem' does not exist" unless File.exists?("#{opts[:destination]}/bin/gem")

@main_dir = opts[:source]
@sync_dir = opts[:destination]
@docstring = opts[:build_docs] ? '--no-ri --no-rdoc' : ''

# Gems you don't want to sync
def get_exceptions
  # Setup hash of common gems that certain ruby installs can't support
  # For now this is just rubynode for REE, feel free to add more
  common_exceptions = {:ree => ["rubynode"]}
  mandated_version = {:ruby187 => ["bleak_house"]}
  returned_exceptions = []
  sync_version = `#{@sync_dir}/bin/gem --version`
  if @sync_dir.match('enterprise')
    returned_exceptions += common_exceptions[:ree]
  end
  if sync_version != '1.8.7'
    returned_exceptions += mandated_version[:ruby187]
  end
  return returned_exceptions
end

def get_file_as_string(filename)
  data = ''
  f = File.open(filename, "r") 
  f.each_line do |line|
    data += line
  end
  return data
end

if source_type == 'directory'
  gem_list = %x[#{@main_dir}/bin/gem list].split("\n")
else
  gem_list = get_file_as_string(opts[:source]).split("\n")
end
  
sync_gem_list = %x[#{@sync_dir}/bin/gem list].split("\n")

# Cleanup gems we know we don't need to update
gems = gem_list - sync_gem_list

for gem in gems
  gem_name = gem.match(/(.*) \((.*)\)/)[1]
  gem_versions = gem.match(/(.*) \((.*)\)/)[2]
  puts "## Checking #{gem_name}"
  if get_exceptions().include?(gem_name)
    puts "This gem is known to be incompatible with the sync'd ruby installation"
    next
  end
  current_gem_info = %x[#{@sync_dir}/bin/gem list #{gem_name}]
  current_gem_info_items = current_gem_info.split("\n")
  for curgem in current_gem_info_items
    curgem_name = curgem.match(/(.*) \((.*)\)/)[1]
    if gem_name == curgem_name
      current_gem_details = curgem
    end
  end
  if current_gem_details.nil? || current_gem_details == "\n" || current_gem_details == ""
    current_gem_versions = []
  else
    current_gem_versions = current_gem_details.match(/(.*) \((.*)\)/)[2].split(", ")
  end
  for version in (gem_versions.split(", ") - current_gem_versions)
    if gem_name == "mysql"
      # Also look for mysql5 type binaries that some package managers use
      mysql_config = `which mysql_config` || `which mysql_config5`
      mysql_dir = `which mysql` || `which mysql5`
      mysql_dir.split('/')[0..-2].join('/')
      system("sudo #{@sync_dir}/bin/gem install #{gem_name} -v #{version} -- --with-mysql-dir=#{mysql_dir} --with-mysql-config=#{mysql_config} #{docstring}")
    else
      system("sudo #{@sync_dir}/bin/gem install #{gem_name} -v #{version} #{@docstring}")
    end
  end
end