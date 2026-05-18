class RemapAppearanceFailResult < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE appearances SET result = 'medical_tap_out' WHERE result = 'fail'"
  end

  def down
    execute "UPDATE appearances SET result = 'fail' WHERE result = 'medical_tap_out'"
  end
end
