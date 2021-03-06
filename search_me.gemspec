files = Dir.glob(Dir.pwd + '/**/*.rb')
#files.select! {|file| !( file =~ /\/db/)} 
files.collect! {|file| file.sub(Dir.pwd + '/', '')}
files.push('LICENSE')

Gem::Specification.new do |s|
  s.name        = 'search_me'
  s.version     = '0.1.2'
	s.date        = "#{Time.now.strftime("%Y-%m-%d")}"
	s.homepage    = 'https://github.com/jphager2/search_me'
  s.summary     = 'Allows you to define attributes of active record model and its related models which will be searched'
  s.description = 'Uses LIKE to search attributes and return any objects of the model for which a match is found'
  s.authors     = ['jphager2']
  s.email       = 'jphager2@gmail.com'
  s.files       = files 
  s.license     = 'MIT'
end
