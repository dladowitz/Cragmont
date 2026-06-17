class Admin::ContentPagesController < Admin::BaseController
  before_action :set_content_page, except: :preview

  def edit
    authorize @content_page
  end

  def update
    authorize @content_page

    if @content_page.update(content_page_params)
      redirect_to edit_admin_content_page_path(@content_page.slug), notice: "Content page was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def preview
    authorize ContentPage

    render html: helpers.render_content_page_markdown(params[:body])
  end

  private

  def set_content_page
    @content_page = ContentPage.current!(params[:slug])
  end

  def content_page_params
    params.require(:content_page).permit(:title, :subtitle, :body)
  end
end
