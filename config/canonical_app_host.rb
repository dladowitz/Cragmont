module CanonicalAppHost
  PUBLIC_DOMAIN = "cragmontclimbing.com"
  WWW_PUBLIC_DOMAIN = "www.#{PUBLIC_DOMAIN}"

  def self.normalize(host)
    host = host.to_s.strip
    host == PUBLIC_DOMAIN ? WWW_PUBLIC_DOMAIN : host
  end
end
