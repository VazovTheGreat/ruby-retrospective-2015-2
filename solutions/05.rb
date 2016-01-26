class Transaction
  attr_reader :message, :result

  def initialize(message, status, result = nil)
    @message = message
    @status = status
    @result = result
  end

  def success?
    @status == true
  end

  def error?
    @status == false
  end
end

class BlobObject
  attr_reader :name, :object
  attr_accessor :to_delete

  def initialize(name, object, to_delete = false)
    @name = name
    @object = object
    @to_delete = to_delete
  end

  def to_delete?
    @to_delete
  end

  def ==(other)
    @name == other.name && @object == other.object
  end
end

class CommitObject
  attr_reader :message, :date, :hash
  attr_accessor :objects

  def initialize(message, objects)
    @message = message
    @date = Time.now
    @formatted = @date.strftime('%a %b %d %H:%M %Y %z')
    @hash = Digest::SHA1.hexdigest("#{@formatted}#{@message}")
    @objects = objects
  end

  def ==(other)
    @hash == other.hash
  end

  def to_s
    "Commit #{@hash}\nDate: #{@formatted}\n\n\t#{@message}"
  end
end

class Branch
  attr_accessor :name, :commits, :staged, :object_state

  def initialize(name, object_store)
    @name = name
    @object_store = object_store
    @commits = []
    @staged = []
    @object_state = []
  end

  def create(branch_name)
    if get_branch_index(
        branch_name).nil?
      new_branch = self.class.new(branch_name, @object_store)
      new_branch.commits = @commits.dup
      @object_store.branches.push(new_branch)
      Transaction.new("Created branch #{branch_name}.", true, new_branch)
    else
      Transaction.new("Branch #{branch_name} already exists.", false)
    end
  end

  def checkout(branch_name)
    branch_index = get_branch_index branch_name
    if branch_index.nil?
      Transaction.new("Branch #{branch_name} does not exist.", false)
    else
      @object_store.work_branch = @object_store.branches[branch_index]
      Transaction.new("Switched to branch #{branch_name}.", true,
                      @object_store.work_branch)
    end
  end

  def remove(branch_name)
    branch_index = get_branch_index branch_name
    if branch_index.nil?
      Transaction.new("Branch #{branch_name} does not exist.", false)
    elsif @object_store.work_branch.name == branch_name
      Transaction.new('Cannot remove current branch.', false)
    else
      @object_store.branches.delete_at(branch_index)
      Transaction.new("Removed branch #{branch_name}.", true)
    end
  end

  def list
    branch_names = @object_store.branches.map(&:name).sort
    branch_names.map! do |branch_name|
      if branch_name == @object_store.work_branch.name
        "* #{branch_name}"
      else
        "  #{branch_name}"
      end
    end
    Transaction.new(branch_names.join("\n"), true)
  end

  def commit_staged
    object_count = staged.length
    staged.each do |object|
      if object.to_delete?
        @object_state.delete(object)
      else
        @object_state.push(object)
      end
    end
    staged.clear
    object_count
  end

  def revert_to_commit(commit_hash)
    commit_index = @commits.index { |commit| commit.hash == commit_hash }
    return false if commit_index.nil?
    @commits.drop(commit_index + 1).each do |commit|
      apply_reverse_commit commit
    end
    @commits = @commits.take(commit_index + 1)
    true
  end

  def staged_object_index(name)
    @staged.index { |item| item.name == name }
  end

  def object_state_index(name)
    @object_state.index { |item| item.name == name }
  end

  def get_branch_index(branch_name)
    @object_store.branches.index { |branch| branch.name == branch_name }
  end

  private
  def apply_reverse_commit(commit)
    commit.objects.each do |object|
      if object.to_delete?
        @object_state.push(object)
      else
        @object_state.delete(object)
      end
    end
  end
end

class ObjectStore
  attr_accessor :branches, :work_branch
  def initialize
    @work_branch = Branch.new('master', self)
    @branches = [@work_branch]
  end

  def self.init(&block)
    object_store = ObjectStore.new
    object_store.instance_eval &block if block_given?
    object_store
  end

  def branch
    @work_branch
  end

  def add(name, object)
    object_index = @work_branch.object_state_index name
    @work_branch.object_state.delete_at object_index unless object_index.nil?
    blob_object = BlobObject.new(name, object)
    @work_branch.staged.push(blob_object)
    Transaction.new("Added #{name} to stage.", true, object)
  end

  def remove(name)
    object_index = @work_branch.object_state_index name
    if object_index.nil?
      Transaction.new("Object #{name} is not committed.", false)
    else
      marked_object = @work_branch.object_state[object_index]
      marked_object.to_delete = true
      @work_branch.staged.push(marked_object)
      Transaction.new("Added #{name} for removal.", true, marked_object.object)
    end
  end

  def commit(message)
    clean = 'Nothing to commit, working directory clean.'
    return Transaction.new(clean, false) if @work_branch.staged.empty?
    stage_clone = @work_branch.staged.clone
    length = @work_branch.commit_staged
    commit = CommitObject.new(message, stage_clone)
    @work_branch.commits.push(commit)
    conduct_output("#{message}\n\t#{length} objects changed", commit)
  end

  def checkout(commit_hash)
    checkout_result = @work_branch.revert_to_commit commit_hash
    if checkout_result
      commit = @work_branch.commits.last
      Transaction.new("HEAD is now at #{commit.hash}.", true, commit)
    else
      Transaction.new("Commit #{commit_hash} does not exist.", false)
    end
  end

  def log
    if @work_branch.commits.empty?
      message = "Branch #{@work_branch.name} does not have any commits yet."
      Transaction.new(message, false)
    else
      Transaction.new(@work_branch.commits.reverse.join("\n\n"), true)
    end
  end

  def get(object_name)
    commit_object = @work_branch.object_state.find do |item|
      item.name == object_name
    end
    if commit_object.nil?
      Transaction.new("Object #{object_name} is not committed.", false)
    else
      message = "Found object #{object_name}."
      Transaction.new(message, true, commit_object.object)
    end
  end

  def head
    if @work_branch.commits.empty?
      message = "Branch #{@work_branch.name} does not have any commits yet."
      Transaction.new(message, false)
    else
      message = "#{@work_branch.commits.last.message}"
      conduct_output(message, @work_branch.commits.last)
    end
  end

  private
  def conduct_output(message, commit)
    output = commit.dup
    output.objects = @work_branch.object_state.map(&:object)
    Transaction.new(message, true, output)
  end
end