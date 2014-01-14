class AddColumnBgColorToAsker < ActiveRecord::Migration
  def change
    add_column :users, :bg_color, :string

    Asker.where(id: 18).first.try :update, {bg_color: '#352726'}
    Asker.where(id: 19).first.try :update, {bg_color: '#012233'}
    Asker.where(id: 22).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 31).first.try :update, {bg_color: '#1B1C20'}
    Asker.where(id: 66).first.try :update, {bg_color: '#C8E2EF'}
    Asker.where(id: 108).first.try :update, {bg_color: '#719297'}
    Asker.where(id: 191).first.try :update, {bg_color: '#EBEBEB'}
    Asker.where(id: 223).first.try :update, {bg_color: '#1B1C20'}
    Asker.where(id: 227).first.try :update, {bg_color: '#8B542B'}
    Asker.where(id: 231).first.try :update, {bg_color: '#012032'}
    Asker.where(id: 284).first.try :update, {bg_color: '#FFF04D'}
    Asker.where(id: 308).first.try :update, {bg_color: '#0099B9'}
    Asker.where(id: 322).first.try :update, {bg_color: '#BADFCD'}
    Asker.where(id: 324).first.try :update, {bg_color: '#BFDFEC'}
    Asker.where(id: 325).first.try :update, {bg_color: '#B2DFDA'}
    Asker.where(id: 326).first.try :update, {bg_color: '#719297'}
    Asker.where(id: 374).first.try :update, {bg_color: '#EDECE8'}
    Asker.where(id: 7362).first.try :update, {bg_color: '#BFDFEC'}
    Asker.where(id: 8367).first.try :update, {bg_color: '#1B1C20'}
    Asker.where(id: 8373).first.try :update, {bg_color: '#B2DFDA'}
    Asker.where(id: 9217).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 10565).first.try :update, {bg_color: '#008FC4'}
    Asker.where(id: 10567).first.try :update, {bg_color: '#C7D590'}
    Asker.where(id: 10572).first.try :update, {bg_color: '#303133'}
    Asker.where(id: 10573).first.try :update, {bg_color: '#F1F1F1'}
    Asker.where(id: 12640).first.try :update, {bg_color: '#FEFEFE'}
    Asker.where(id: 12982).first.try :update, {bg_color: '#1D1815'}
    Asker.where(id: 13588).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 14106).first.try :update, {bg_color: '#E8E0D5'}
    Asker.where(id: 19454).first.try :update, {bg_color: '#DEEAF7'}
    Asker.where(id: 24740).first.try :update, {bg_color: '#DEDDE9'}
    Asker.where(id: 26070).first.try :update, {bg_color: '#012032'}
    Asker.where(id: 26522).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 27857).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 28064).first.try :update, {bg_color: '#1B1C20'}
    Asker.where(id: 32575).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 32584).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 34320).first.try :update, {bg_color: '#719297'}
    Asker.where(id: 34530).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 34534).first.try :update, {bg_color: '#C4E0EC'}
    Asker.where(id: 34662).first.try :update, {bg_color: '#EBEBEB'}
  end
end
