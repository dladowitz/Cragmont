module Ui
  class BrandComponent < BaseComponent
    TEMPLATE = "ui/brand"
    attr_reader :url

    def initialize(url:, **attributes)
      super(**attributes)
      @url = url
      add_classes("site-name")
    end
  end
end
