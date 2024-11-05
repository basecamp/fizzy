class ProjectsController < ApplicationController
  before_action :set_project, except: %i[ new create ]

  def new
    @project = Project.new
  end

  def create
    @project = Project.create! project_params
    redirect_to bubbles_path(bucket_ids: @project.bucket)
  end

  def edit
    selected_user_ids = @bucket.users.pluck :id
    @selected_users, @unselected_users = Current.account.users.active.alphabetically.partition { |user| selected_user_ids.include? user.id }
  end

  def update
    @project.update! project_params
    @bucket.accesses.revise granted: grantees, revoked: revokees

    redirect_to bubbles_path(bucket_ids: @bucket)
  end

  private
    def set_project
      @bucket = Current.user.buckets.projects.find params[:id]
      @project = @bucket.project
    end

    def project_params
      params.expect project: [ :name ]
    end

    def grantees
      Current.account.users.active.where id: grantee_ids
    end

    def revokees
      @bucket.users.where.not id: grantee_ids
    end

    def grantee_ids
      params.fetch :user_ids, []
    end
end
