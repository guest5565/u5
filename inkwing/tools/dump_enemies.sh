#!/bin/bash
# renders ${OUT:-previews/enemies.png} from EnemyModel.lua (az arg optional)
cd ~/Inkwing
{ cat tools/mock/rbx.lua; echo 'local EM=(function()'; cat src/ReplicatedStorage/Shared/EnemyModel.lua; echo 'end)()';
  for k in ${KINDS:-InkBlob ScribbleBat PaperWasp InkShade BlotKing}; do echo "do local e=EM.build('$k',{}) EM.pose(e,CFrame.Angles(0,math.pi,0),0.3) dump('$k') end"; done; } > /tmp/em.lua
~/tools/luau /tmp/em.lua > /tmp/em.out && python3 tools/render_dump.py /tmp/em.out ${1:-25} ${OUT:-previews/enemies.png} && echo rendered
