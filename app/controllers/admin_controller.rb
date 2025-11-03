class AdminController < ApplicationController
  before_action :ensure_staff
end
