module Yabeda
  module SolidQueue
    def self.install!
      Yabeda.configure do
        group :solid_queue

        gauge :jobs_failed_count, comment: "Number of failed jobs"
        gauge :jobs_unreleased_count, comment: "Number of claimed jobs that don't belong to any process"
        gauge :jobs_scheduled_and_delayed_count, comment: "Number of scheduled jobs that have over 5 minutes delay"
        gauge :recurring_tasks_count, comment: "Number of recurring jobs scheduled"
        gauge :recurring_tasks_delayed_count, comment: "Number of recurring jobs that haven't been enqueued within their schedule"

        collect do
          if ::SolidQueue.supervisor?
            solid_queue.jobs_failed_count.set({}, ::SolidQueue::FailedExecution.count)
            solid_queue.jobs_unreleased_count.set({}, ::SolidQueue::ClaimedExecution.where(process: nil).count)
            solid_queue.jobs_scheduled_and_delayed_count.set({}, ::SolidQueue::ScheduledExecution.where(scheduled_at: ..5.minutes.ago).count)
            solid_queue.recurring_tasks_count.set({}, ::SolidQueue::RecurringTask.count)
            solid_queue.recurring_tasks_delayed_count.set({}, ::SolidQueue::RecurringTask.count do |task|
              task.last_enqueued_time.present? && (task.previous_time - task.last_enqueued_time) > 5.minutes
            end)
          end
        end
      end
    end
  end
end
