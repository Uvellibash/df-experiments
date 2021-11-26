--DON'T RUN THIS SCRIPT IF YOUR SAVEFILE IS DEAR TO YOU
--For experimenting purposes only! Script is unfinished

--KNOWN BUGS:
--TODO: If stack of roasts is lying on the floor, separated meals are invisible until haulers pick them
--TODO: 'TSK' is not showing up when meal is in job
--THINGS TO CHECK:
--TODO: Aren't depot jobs get canceled when merchants leave?
--TODO: What happens if game exit in the middle of the job?
--THINGS TO IMPROVE:
--TODO: Assign dwarves food according to their preferences


-- Next part is copy-pasted from DFHack's gui.advfort
-- Credit goes to the authors!
-- Here copy-paste starts:
local gscript=require 'gui.script'

function smart_job_delete( job )
    local gref_types=df.general_ref_type
    for i,v in ipairs(job.general_refs) do
        if v:getType()==gref_types.BUILDING_HOLDER then
            local b=v:getBuilding()
            if b then
                for i,v in ipairs(b.jobs) do
                    if v==job then
                        b.jobs:erase(i)
                        break
                    end
                end
            else
                print("Warning: building holder ref was invalid while deleting job")
            end
        elseif v:getType()==gref_types.UNIT_WORKER then
            local u=v:getUnit()
            if u then
                u.job.current_job =nil
            else
                print("Warning: unit worker ref was invalid while deleting job")
            end
        else
            print("Warning: failed to remove link from job with type:",gref_types[v:getType()])
        end
    end
    --unlink job
    local link=job.list_link
    if link.prev then
        link.prev.next=link.next
    end
    if link.next then
        link.next.prev=link.prev
    end
    link:delete()
    --finally delete the job
    job:delete()
end

function make_native_job(args)
    if args.job == nil then
        local newJob=df.job:new()
        newJob.id=df.global.job_next_id
        df.global.job_next_id=df.global.job_next_id+1
        newJob.flags.special=true
        newJob.job_type=args.job_type
        newJob.completion_timer=-1

        newJob.pos:assign(args.pos)
        --newJob.pos:assign(args.unit.pos)
        args.job=newJob
        args.unlinked=true
    end
end

function AssignBuildingRef(args)
    local bld=args.building or dfhack.buildings.findAtTile(args.pos)
    args.job.general_refs:insert("#",{new=df.general_ref_building_holderst,building_id=bld.id})
    bld.jobs:insert("#",args.job)
    args.building=args.building or bld
    return true
end

function AssignUnitToJob(job,unit,unit_pos)
    job.general_refs:insert("#",{new=df.general_ref_unit_workerst,unit_id=unit.id})

    unit.job.current_job=job
    unit_pos=unit_pos or {x=job.pos.x,y=job.pos.y,z=job.pos.z}
    unit.path.dest:assign(unit_pos)
    return true
end
-- Here copy-paste Ends

-- Free vector to prevent goose egg case mentioned above
function freeVector(vector)
  if #vector == 0 then
    return
  end
  for i=#vector-1,0,-1 do
    vector:erase(i)
  end
end

-- Separate one prepared meal from a stack of Prepared meals
function get1MealFromStack(stack)
  --TODO: Check if it is actually a stack of Prepared meals...
  local stackSize =  stack:getStackSize()
  if stackSize > 1 then
    --duplicate = dfhack.items.createItem(dfhack.items.findType(item), item.subtype, item.mat_type, item.mat_index, servant)
    print('before new')
    local duplicate = df.item_foodst:new()
    print('after new')


    stack:setStackSize(stackSize - 1)
    --duplicate.pos = item.pos:new()
    duplicate:assign(stack)
    duplicate.id = df.global.item_next_id
    df.global.item_next_id = df.global.item_next_id + 1
    freeVector(duplicate.general_refs)
    freeVector(duplicate.specific_refs)
    freeVector(duplicate.ingredients)
    for c,i in ipairs(stack.ingredients) do
      duplicate.ingredients:insert("#",{new=true,item_type=i.item_type, mat_type=i.mat_type,mat_index=i.mat_index, maker=i.maker, quality=i.quality})
    end

    --duplicate.pos:assign(xyz2pos(dfhack.items.getPosition(stack)))
    --duplicate.flags:assign(stack.flags:new())
    --duplicate.flags2:assign(stack.flags2:new())
    --duplicate.weight = stack.weight
    --duplicate.weight_fraction = stack.weight_fraction
    --duplicate.temperature:assign(stack.temperature:new())
    --duplicate.mat_state:assign(stack.mat_state:new())
    --duplicate.mat_tykpe = stack.mat_type
    --duplicate.mat_index = stack.mat_index
    duplicate:setStackSize(1)

    print('before insert')
    df.global.world.items.all:insert("#",duplicate)

    local sourceContainer = dfhack.items.getContainer(stack)
    if(sourceContainer) then
        print("in container")
        duplicate.general_refs:insert("#",{new=df.general_ref_contained_in_itemst,item_id=sourceContainer.id})
        sourceContainer.general_refs:insert("#",{new=df.general_ref_contains_itemst,item_id=duplicate.id})
        --local moveResult = dfhack.items.moveToContainer(duplicate,sourceContainer)
        --print("move result ",moveResult)
    end
    print('duplicate_id',duplicate.id)
    print('item_id',stack.id)
      --item = duplicate
    return duplicate
  else
    return stack
  end
end

trackedItems = trackedItems or {}

function makeServeFoodJob(target_building_id)
  local stack_id = findMeal()
  if(stack_id == nil) then return end
  --local servant = df.unit.find(servant_id)
  local stack = df.item.find(stack_id)
  local targetBuilding = df.building.find(target_building_id)
  local item = get1MealFromStack(stack)

  local pos =  df.coord:new()
  pos.x = targetBuilding.centerx
  pos.y = targetBuilding.centery
  pos.z = targetBuilding.z
  --local pos =  targetBuilding.pos
  local from_pos = copyall(item.pos)

  if pos ~= nil then
    --gscript.start(function ()

    --only this job and "display item" job can be used to place item in building
    --perhaps other job-types have more safety-checks
    args = {job_type=df.job_type.BringItemToDepot,pos=pos}
    make_native_job(args)
    AssignBuildingRef(args)
    --args.job.items:insert("#",{new=true,item=container,role=df.job_item_ref.T_role.QueuedContainer,job_item_idx=args.job.id})

    args.job.items:insert("#",{new=true,item=item,role=df.job_item_ref.T_role.Hauled,job_item_idx=args.job.id})
    --args.job.flags.do_now = true

    --Anybody can be assigned to job, even children
    --AssignUnitToJob(args.job,servant,args.from_pos)

    dfhack.job.linkIntoWorld(args.job,true)
    item.flags.in_job = true
    table.insert(trackedItems,{building_id=target_building_id, item_id=item.id, job_id=args.job.id});
    print('job linked')
    --end)
  end
end

function tableIsBeingServed(table_id)
  for k,t in ipairs(trackedItems) do
    if(table_id == t.building_id) then
      return true
    end
  end
  return false
end
-- We need to change meal ownership after it makes it's way to the table
function checkTrackedItems()
  for i=#trackedItems,1,-1 do
    local item =  df.item.find(trackedItems[i].item_id)
    if(item == nil) then
      print("item lost")
      table.remove(trackedItems,i)
      --TODO: remove item
    else
      if (item.flags.in_job == false) then
        if(item.flags.in_building == true) then
          onItemPlacedInContainer(item,trackedItems[i])
          table.remove(trackedItems,i)
        else
          print("item not ended up placed in container for some reason")
          table.remove(trackedItems,i)
        end
      end
        --for j=#item.general_refs-1,0,-1 do
          --if(df.general_ref_building_holderst:is_instance(item.general_refs[j])) then
          --  item.general_refs[j].building_id
          --end
          --if(df.general_ref_unit_tradebringerst:is_instance(item.general_refs[j])) then
          --  item.general_refs:erase(j)
          --  print('deleted it')
          --else
          --  print(item.general_refs[j]:getType(), df.general_ref_unit_tradebringerst)
          --end
        --end
      --end
    end
  end
  if(#trackedItems>0) then
    print("next check scheduled in 100 ticks. Items tracked count= ",#trackedItems)
    trackingTimeout = dfhack.timeout(100,'ticks',checkTrackedItems)
  else
    print("trackedItems==0")
    trackingTimeout = nil
  end
end

function getBuildingHolder(item)
  for j=#item.general_refs-1,0,-1 do
    if(df.general_ref_building_holderst:is_instance(item.general_refs[j])) then
      return df.building.find(item.general_refs[j].building_id)
    end
  end
end

function getContainer(item)
  for j=#item.general_refs-1,0,-1 do
    if(df.general_ref_unit_tradebringerst:is_instance(item.general_refs[j])) then
      item.general_refs:erase(j)
    end
  end
end
function onItemPlacedInContainer(item,itemInfo)
  local containerHolder = df.building.find(itemInfo.building_id)
  --if(targetContainer == nil) then
  --  print("target container lost")
  --  return
  --end
  local buildingHolder = getBuildingHolder(item)
--  local containerHolder = getBuildingHolder(targetContainer)
  if(buildingHolder == nil) then
    print("item not ended up being placed in building")
    return
  end
  if(buildingHolder.id ~= containerHolder.id) then
    print("item ended up being placed in wrong building")
    return
  end

  -- let's remove traces of "bring into depot":
  item.flags.in_building = false
  for j=#item.general_refs-1,0,-1 do
    if(df.general_ref_unit_tradebringerst:is_instance(item.general_refs[j])) then
      item.general_refs:erase(j)
    end
  end

  -- now let's set ownership for a meal
  local unitOwner = df.unit.find( buildingHolder.owner_id)
  if(unitOwner ~= nil) then
    dfhack.items.setOwner(item,unitOwner)
  end
  if(unitOwner == nil) then
    --it is not the main table in the room
    --find owner of the main table and then his spouse
    --set ownership to owner's spouse
    if(#buildingHolder.parents ~= 0) then

      local mainBuilding = df.building.find(buildingHolder.parents[0].id)
      if(mainBuilding == nil) then return end

      local mainBuildingOwner = df.unit.find(mainBuilding.owner_id)
      if(mainBuildingOwner == nil) then return end

      local ownerSpouse = df.unit.find(mainBuildingOwner.relationship_ids.Spouse)
      if(ownerSpouse == nil) then return end
      dfhack.items.setOwner(item,ownerSpouse)
    end
  end
end
--item = dfhack.gui.getSelectedItem(true)
--printall(container.pos)
--local pos =  df.coord:new()
--pos.x = 108
--pos.y = 138
--pos.z = 131
--pos.x = 57
--pos.y = 122
--pos.z = 144
--for _, act_id in ipairs(servant.social_activities) do
--    local act = df.activity_entry.find(act_id)
--    if act and act.type == 8 then
--        act.events[0].flags.dismissed = true
--    end
--end
function findMeal()
  for k,o in ipairs(df.global.world.items.all) do
    if df.is_instance( df.item_foodst,o) then
      if((o.flags.in_job==false) and (o.flags.in_building==false ) and (o.flags.forbid==false ) and (o.flags.dump==false )) then
        local unitOwner = dfhack.items.getOwner(o)
        if(unitOwner==nil) then
          return (o.id)
        end
      end
    end
  end
end

diningRooms = diningRooms or {}
function getAllDiningRooms()
  diningRooms = {}
  for k,o in ipairs(df.global.world.buildings.all) do
    if df.is_instance( df.building_tablest,o) then
      if(o.owner_id>0) then
        local roomInfo = {owner_id=o.owner_id, id=o.id}
        local emptyTables = {}
        local nonEmptyTables = {}

        if((#o.contained_items > 1) or tableIsBeingServed(o.id)) then
          table.insert(nonEmptyTables,o.id)
        else
          table.insert(emptyTables,o.id)
        end

        local spouse = df.unit.find(o.owner.relationship_ids.Spouse)

        if(spouse ~=nil) then
          roomInfo.spouse_id = spouse.id
        end

        for k2,o2 in ipairs(o.children) do
          if(df.is_instance( df.building_tablest,o2)) then
            if((#o2.contained_items > 1) or tableIsBeingServed(o2.id)) then
              table.insert(nonEmptyTables,o2.id)
            else
              table.insert(emptyTables,o2.id)
            end
          end
        end
        roomInfo.nonEmptyTables = nonEmptyTables
        roomInfo.emptyTables = emptyTables
        table.insert(diningRooms, roomInfo)
      end
    end
  end
end

print("tracked items:")
for a,b in ipairs(trackedItems) do
  printall(b)
end

print("dining Rooms:")
for a,b in ipairs(diningRooms) do
  printall(b)
end

function serveAllTables()
  getAllDiningRooms()
  for _, diningRoomInfo in pairs(diningRooms) do
    servingsNeeded = 1
    if(diningRoomInfo.spouse_id ~= nil) then
      servingsNeeded = 2
    end
    servingsNeeded = servingsNeeded - #diningRoomInfo.nonEmptyTables
    print('servingsNeeded', servingsNeeded)
    if(servingsNeeded >0 and #diningRoomInfo.emptyTables>0) then
      makeServeFoodJob(diningRoomInfo.emptyTables[1])
    end
    if(servingsNeeded >1 and #diningRoomInfo.emptyTables>1) then
      makeServeFoodJob(diningRoomInfo.emptyTables[2])
    end
  end
end

serveAllTables()
if (trackingTimeout==nil or (not dfhack.timeout_active(trackingTimeout))) then
  trackingTimeout = dfhack.timeout(100,'ticks',checkTrackedItems)
else
  print("no timeout needed ", trackingTimeout)
end
