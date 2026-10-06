require "test_helper"

class AlbumCoverTest < ActiveSupport::TestCase
  ALBUM = "https://photos.app.goo.gl/crew".freeze
  SHARE = "https://photos.google.com/share/AF1Qcrew?key=abc".freeze
  COVER = "https://lh3.googleusercontent.com/pw/AP1Gcrew".freeze

  setup do
    @requests = []
    @responses = {}
    requests, responses = @requests, @responses
    @original_get = AlbumCover.method(:get)
    AlbumCover.define_singleton_method(:get) do |uri|
      requests << uri.to_s
      responses.fetch(uri.to_s) { [ 404, nil, "" ] }
    end
  end

  teardown { AlbumCover.define_singleton_method(:get, @original_get) }

  test "refresh follows the share link and saves the uncropped album cover without metadata" do
    album_page(cover: "#{COVER}=w600-h315-p-k")
    @responses["#{COVER}=w960-h960"] = [ 200, nil, jpeg(1600, 1200, xmp: "secret-gps") ]

    cover = AlbumCover.refresh(ALBUM)

    assert_equal [ ALBUM, SHARE, "#{COVER}=w960-h960" ], @requests
    assert_equal "#{COVER}=w960-h960", cover.source_url
    assert_equal "image/jpeg", cover.image.content_type
    saved = Vips::Image.new_from_buffer(cover.image.download, "")
    assert_equal [ 960, 720 ], [ saved.width, saved.height ]
    refute_includes saved.get_fields, "xmp-data"
    refute_includes cover.image.download, "secret-gps"
  end

  test "an unchanged cover is not downloaded again and a new cover replaces the copy" do
    album_page(cover: "#{COVER}=w600-h315-p-k")
    @responses["#{COVER}=w960-h960"] = [ 200, nil, jpeg(720, 960) ]
    blob = AlbumCover.refresh(ALBUM).image.blob

    @requests.clear
    assert_equal blob, AlbumCover.refresh(ALBUM).image.blob
    assert_equal [ ALBUM, SHARE ], @requests

    album_page(cover: "#{COVER}-new=w600-h315-p-k")
    @responses["#{COVER}-new=w960-h960"] = [ 200, nil, jpeg(960, 640) ]
    cover = AlbumCover.refresh(ALBUM)
    assert_not_equal blob, cover.image.blob
    assert_equal "#{COVER}-new=w960-h960", cover.source_url
    assert_equal 1, AlbumCover.count
  end

  test "every hop and the cover image must stay on Google" do
    assert_nil AlbumCover.refresh("https://evil.test/album")
    assert_nil AlbumCover.refresh("http://photos.app.goo.gl/crew")
    assert_empty @requests

    @responses[ALBUM] = [ 302, "https://evil.test/share", "" ]
    assert_nil AlbumCover.refresh(ALBUM)
    assert_equal [ ALBUM ], @requests

    [ "https://evil.test/cover", "http://lh3.googleusercontent.com/pw/x", "https://googleusercontent.com.evil.test/x" ].each do |source|
      @requests.clear
      album_page(cover: source)
      assert_nil AlbumCover.refresh(ALBUM)
      assert_equal [ ALBUM, SHARE ], @requests
    end

    @responses[ALBUM] = [ 302, ALBUM, "" ]
    assert_nil AlbumCover.refresh(ALBUM)
    assert_equal 0, AlbumCover.count
  end

  test "a failed refresh keeps the last saved cover" do
    album_page(cover: COVER)
    @responses["#{COVER}=w960-h960"] = [ 200, nil, jpeg(720, 960) ]
    blob = AlbumCover.refresh(ALBUM).image.blob

    failures = {
      "album error" => -> { @responses[SHARE] = [ 500, nil, "" ] },
      "no og:image" => -> { @responses[SHARE] = [ 200, nil, "<html><head></head></html>" ] },
      "not an image" => -> { album_page(cover: "#{COVER}-html"); @responses["#{COVER}-html=w960-h960"] = [ 200, nil, "<html>sign in</html>" ] },
      "damaged image" => -> { album_page(cover: "#{COVER}-bad"); @responses["#{COVER}-bad=w960-h960"] = [ 200, nil, jpeg(720, 960).byteslice(0, 600) ] }
    }
    failures.each do |name, setup|
      setup.call
      assert_nil AlbumCover.refresh(ALBUM), name
      cover = AlbumCover.find_by!(album_url: ALBUM)
      assert_equal blob, cover.image.blob, name
      assert_equal "#{COVER}=w960-h960", cover.source_url, name
    end
  end

  private

  def album_page(cover:)
    @responses[ALBUM] = [ 302, SHARE, "" ]
    @responses[SHARE] = [ 200, nil, %(<html><head><meta property="og:title" content="Crew"><meta property="og:image" content="#{cover}"></head></html>) ]
  end

  def jpeg(width, height, xmp: nil)
    image = Vips::Image.black(width, height, bands: 3) + [ 90, 120, 150 ]
    image = image.mutate { |copy| copy.set_type!(Vips::BLOB_TYPE, "xmp-data", "<x:xmpmeta>#{xmp}</x:xmpmeta>") } if xmp
    image.cast(:uchar).jpegsave_buffer
  end
end
