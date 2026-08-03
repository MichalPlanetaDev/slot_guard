namespace :demo do
  desc "Restore the public SlotGuard demo workspace"
  task reset: :environment do
    workspace = Demo::Reset.call

    puts "Restored #{workspace.name}."
    puts "Demo account: #{Demo::Reset::OWNER_EMAIL}"
  rescue Demo::Reset::Disabled
    abort "Set DEMO_MODE=true before resetting demo data."
  end
end
