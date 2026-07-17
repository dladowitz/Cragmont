class Admin::PartnerCompaniesController < Admin::BaseController
  before_action :set_partner_company, only: %i[show edit update destroy]

  def index
    authorize PartnerCompany
    @partner_companies = PartnerCompany.order(:name)
  end

  def show
    authorize @partner_company
  end

  def new
    @partner_company = PartnerCompany.new
    authorize @partner_company
  end

  def edit
    authorize @partner_company
  end

  def create
    @partner_company = PartnerCompany.new(partner_company_params)
    authorize @partner_company

    if @partner_company.save
      redirect_to admin_partner_company_path(@partner_company), notice: "On belay! Partner company was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @partner_company

    if @partner_company.update(partner_company_params)
      redirect_to admin_partner_company_path(@partner_company), notice: "On belay! Partner company was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @partner_company

    if @partner_company.destroy
      redirect_to admin_partner_companies_path, notice: "Partner company was deleted.", status: :see_other
    else
      redirect_to admin_partner_company_path(@partner_company),
        alert: "Partner company cannot be deleted while classes are assigned to it.",
        status: :see_other
    end
  end

  private

  def set_partner_company
    @partner_company = PartnerCompany.find(params[:id])
  end

  def partner_company_params
    params.require(:partner_company).permit(
      :name,
      :website_url,
      :primary_contact_name,
      :primary_contact_phone,
      :primary_contact_email,
      :secondary_contact_name,
      :secondary_contact_phone,
      :secondary_contact_email,
      :description
    )
  end
end
