class Admin::TripTransactionsController < ApplicationController
  before_action :set_trip

  def index
    @ledger_entries = TripTransactionLedger.call(@trip)
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end
end
