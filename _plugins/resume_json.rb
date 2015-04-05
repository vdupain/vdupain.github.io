# _plugins/resume_json.rb
 
require 'oauth'
require 'yaml'
require 'json'
 
module Jekyll
  class Resume < Jekyll::Generator
    def format_date(date)
      Date.new(date['year'], date['month']).strftime('%b %Y').to_s
    end
 
    def format_position!(position)
      position['startDate'] = format_date(position['startDate'])
      position['endDate'] = position['endDate'] ? format_date(position['endDate']) : 'present'
      position
    end
 
    def generate(site)
      oauth = YAML.load_file('_linkedin_oauth.yml')
      consumer_options = {
        site: 'https://api.linkedin.com',
        authorize_path: '/uas/oauth/authorize',
        request_token_path: '/uas/oauth/requestToken',
        access_token_path: '/uas/oauth/accessToken'
      }
 
      consumer = OAuth::Consumer.new(oauth['consumer_key'], oauth['consumer_secret'], consumer_options)
      access_token = OAuth::AccessToken.new(consumer, oauth['oauth_token'], oauth['oauth_secret'])
 
      url = CGI::escape('http://www.linkedin.com/in/vdupain')
      fields = [
        'first-name',
        'last-name',
        'location:(name)',
        'picture-url',
        'positions',
        'projects',
        'educations'
      ].join(',')
 
      resume_json_text = access_token.get("http://api.linkedin.com/v1/people/url=#{url}:(#{fields})", 'x-li-format' => 'json').body
      resume_json = JSON.parse(resume_json_text)
      resume_json['positions']['values'].map! { |position| format_position!(position) }
 
      resume_page = site.pages.detect {|page| page.name == 'resume.html'}
      resume_page.data['resume'] = resume_json
    end
  end
end
