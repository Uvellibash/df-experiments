unit = dfhack.gui.getSelectedUnit(true)
if (unit) then
	print("unit ", unit.id, " hunger: ",unit.counters2.hunger_timer)
  unit.counters2.hunger_timer = 50000
else
  print("no unit selected")
end
