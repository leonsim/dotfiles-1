#!/usr/bin/env ruby
# encoding: utf-8

# Rename file name to use hyphen as delimit
#
# Usage: ./hyphen-rename.rb filename.pdf
#

def slug(str)
  str.downcase
     .gsub(/[^\w\p{Han}]/, '-')
     .gsub(/^a-|-a-|-s-|-+|_/, '-') # remove a, xx's
     .gsub(/-(t)-/, '\1-') # replace xx't to xxt
     .gsub(/^-|-$/, '')
end

if ARGV.length != 1
  STDERR << "Usage: #{$PROGRAM_NAME} filename.pdf\n"
  exit 1
end

files = if File.directory?(ARGV[0])
          Dir.glob(File.join(ARGV[0], "**/*"))
        elsif File.exist?(ARGV[0])
          [ARGV[0]]
        else
          STDERR << "File/Path not found\n"
          exit 2
        end

files.each do |file|
  path, name = File.split(file)

  extname = File.extname(name)
  basename = slug(File.basename(name, extname))
  if basename.empty?
    STDERR << "Unknown name: #{name}"
    next
  end

  new_file = File.join(path, "#{basename}#{extname}")
  if file.casecmp(new_file) == 0
    if file != new_file # however, not in same case
      File.rename(file, new_file)
    else
      next
    end
  elsif File.exist?(new_file)
    STDERR << "File existed: #{new_file}\n"
  else
    File.rename(file, new_file)
  end
end
