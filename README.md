# Resque::Stages

A Resque plugin for executing jobs in stages.  Groups are created each
with multiple stages.  Each stage contains a number of Jobs.  All jobs
within a stage must complete before the next stage is executed.  What
makes this gem special is that it will wait for jobs to Retry before
they are considered complete and the next stage will be executed.

Once all jobs in all stages are complete, the stages and jobs are all
deleted - cleaning up after itself.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'resque-stages'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install resque-stages

## Usage

###Basic Usage

Include the stages plugin in all jobs that will be enqueued as a part of
a Stage.  Do not worry, you will not have to enqueue the job only as
part of a stage.  You will be able to use the job inside of or outside
of a stage.

This gem will enqueue a job with extra paramters when it is enqueued
as a part of a stage.  To support this, the
`Resque::Plugins::Stages::StagedJob.perform_job` method will return an
object which will have the un-altered arguments for the job - whether or
not the job is called with the extra parameters.

```Ruby
class MyJob
  extend Resque::Plugins::Retry
  include Resque::Plugins::Stages
  
  def perform(*args)
    job = Resque::Plugins::Stages::StagedJob.perform_job(*args)
    
    real_perform(*job.args)
  end

  # The "old" perform function can be called here as-is because the
  # perform_job will always ensure that the original parameters are called
  def real_perform(my_param_1, my_param_2)
  end
end
```

To create a grouping of stages and execute the jobs, you then create a
group and the stages you need in it:

```Ruby
def enqueue_stages
  Resque::Plugins::Stages::StagedGroup.within_a_grouping do |grouping|
    stage = grouping.stage(1)
    
    12.times do |index|
      stage.enqueue MyJob, index, "parameter"
    end

    stage = grouping.stage(2)
    stage.enqueue MyJob, -1, "summary"
  end
end
```

`within_a_grouping` will `initiate` the first stage when it completes.
This will cause all jobs in stage 1 to complete before stage 2 executes.

NOTE:  All jobs and stages in a grouping are kept until the last job in
the last stage completes so that you can query the jobs to find out which
ones completed successfully and which ones failed.

To aid in querying information about the jobs in a stage, each job
includes a single string value `status_message` which can be set at any
time and will be available until all jobs are completed.

###API

**StagedJob** - A job that is a part of a Stage

The Staged Job is the job which has been enqueued and using
the `perform_job` will be available to you within your `perform` method.

```Ruby
job = Resque::Plugins::Stages::StagedJob.perform_job(*args)

job.args               # The original args to the job
job.blank?             # true if there is no job or stage/grouping etc.
job.staged_group_stage # The stage that the job is a part of.
job.status             # The status of the job
                       # Valid statuses:
                       #    :pending
                       #    :queued
                       #    :running
                       #    :pending_re_run
                       #    :failed
                       #    :successful
job.status_message     # A message that you can set on the job
job.class_name         # The name of the jobs class
job.queue_time         # The time that the job was initially enqueued
job.delete             # Delete the job.  It may remain in the Resque queue
job.enqueue_job        # Enque the job (Will enqueue from the delay queue if retrying)
job.completed?         # True if the job is :failed or :successful
job.queued?            # True if the job has been queued to Resque
job.pending?           # True if the job is :pending or :pending_re_run

# To get the group so you can see other stages: 
job.staged_group_stage&.staged_group
```

**StagedGroupStage** - A Stage that is a part of a Group (contains Jobs)

```Ruby
job = Resque::Plugins::Stages::StagedJob.perform_job(*args)
stage = job.staged_group_stage

## OR
stage = group.stage(1)

stage.enqueue                 # Add a job to a stage
stage.enqueue_to              #   If a stage is running, then
stage.enqueue_at              #   the job is enqueued immediately
stage.enqueue_at_with_queue   #   using the enqueue method specified
stage.enqueue_in              #   otherwise it is simply enqueued
stage.enqueue_in_with_queue   #   when the stage is initiated
stage.status                  # The status of the stage
                              #   Valid statuses:
                              #     :pending
                              #     :running
                              #     :complete
stage.number                  # The stages number
stage.staged_group            # The group the stage belongs to
stage.jobs                    # The jobs for the stage in the order they
                              #   were enqueued
stage.num_jobs                # The number of jobs in the stage
stage.delete                  # Delete the stage
stage.initiate                # Enqueue all jobs in the stage.
                              #   Once all jobs compelte, the next stage
                              #   will be initiated.
stage.blank?                  # Returns true if the stage does not really exist.
```


**StagedGroup** - A group of stages

```Ruby
Resque::Plugins::Stages::StagedGroup.within_a_grouping("description") do |group|
  group.initiate      # Find the next stage that is not complete and initiate it
  group.description   # The description that was provided for the group
  group.created_at    # The date/time that the group was created.
  group.current_stage # The first non-complete stage.
  group.stage(number) # The indicated stage.  Will create a stage if none found.
  group.stages        # A hash of all of the stages.  The stage numbers
                      #   will be the key values.
  group.delete        # Delete the group and all stages and jobs.
  group.blank?        # Returns true if the group is not saved
end
```

**Cleaner** - A cleaner utility class for fixing up mixed up jobs

```Ruby
Resque::Plugins::Stages::Cleaner.purge_all    # delete all values from Redis
Resque::Plugins::Stages::Cleaner.cleanup_jobs # Create any stages or groups
                                              #  needed for orphaned jobs.
```

## Screenshots

### Groups
![Pending Job Details](https://raw.githubusercontent.com/RealNobody/resque-stages/master/read_me/groups_list.png)

### Stages
![Pending Job Details](https://raw.githubusercontent.com/RealNobody/resque-stages/master/read_me/stages.png)

### Jobs
![Pending Job Details](https://raw.githubusercontent.com/RealNobody/resque-stages/master/read_me/stage.png)

### Job
![Pending Job Details](https://raw.githubusercontent.com/RealNobody/resque-stages/master/read_me/job.png)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/resque-stages. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/resque-stages/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Resque::Stages project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/resque-stages/blob/master/CODE_OF_CONDUCT.md).
