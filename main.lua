require 'engine'
require 'localization'
require 'localized_tables'
require 'shared'
require 'arena'
require 'mainmenu'
require 'buy_screen'
require 'objects'
require 'player'
require 'enemies'
require 'media'
require 'accessibility'
require 'tutorial'


function init()
  -- Before anything that builds a string. The save file has already been read
  -- by this point, which is where the chosen language lives.
  loc.init()
  build_localized_tables()
  table.insert(loc.on_change, build_localized_tables)

  shared_init()

  input:bind('move_left', {'a', 'left', 'dpleft', 'm1'})
  input:bind('move_right', {'d', 'e', 's', 'right', 'dpright', 'm2'})
  input:bind('enter', {'space', 'return', 'fleft', 'fdown', 'fright'})

  local s = {tags = {sfx}}
  artificer1 = Sound('458586__inspectorj__ui-mechanical-notification-01-fx.ogg', s)
  explosion1 = Sound('Explosion Grenade_04.ogg', s)
  mine1 = Sound('Weapon Swap 2.ogg', s)
  level_up1 = Sound('Buff 4.ogg', s)
  unlock1 = Sound('Unlock 3.ogg', s)
  gambler1 = Sound('Collect 5.ogg', s)
  usurer1 = Sound('Shadow Punch 2.ogg', s)
  orb1 = Sound('Collect 2.ogg', s)
  gold1 = Sound('Collect 5.ogg', s)
  gold2 = Sound('Coins - Gears - Slot.ogg', s)
  psychic1 = Sound('Magical Impact 13.ogg', s)
  fire1 = Sound('Fire bolt 3.ogg', s)
  fire2 = Sound('Fire bolt 5.ogg', s)
  fire3 = Sound('Fire bolt 10.ogg', s)
  earth1 = Sound('Earth Bolt 1.ogg', s)
  earth2 = Sound('Earth Bolt 14.ogg', s)
  earth3 = Sound('Earth Bolt 20.ogg', s)
  illusion1 = Sound('Buff 5.ogg', s)
  thunder1 = Sound('399656__bajko__sfx-thunder-blast.ogg', s)
  flagellant1 = Sound('Whipping Horse 3.ogg', s)
  bard2 = Sound('376532__womb-affliction__flute-trill.ogg', s)
  arcane2 = Sound('Magical Impact 12.ogg', s)
  frost1 = Sound('Frost Bolt 20.ogg', s)
  arcane1 = Sound('Magical Impact 26.ogg', s)
  pyro1 = Sound('Fire bolt 5.ogg', s)
  pyro2 = Sound('Explosion Fireworks_01.ogg', s)
  dot1 = Sound('Magical Swoosh 18.ogg', s)
  gun_kata1 = Sound('Pistol Shot_07.ogg', s)
  gun_kata2 = Sound('Pistol Shot_08.ogg', s)
  dual_gunner1 = Sound('Revolver Shot_07.ogg', s)
  dual_gunner2 = Sound('Revolver Shot_08.ogg', s)
  ui_hover1 = Sound('bamboo_hit_by_lord.ogg', s)
  ui_switch1 = Sound('Switch.ogg', s)
  ui_switch2 = Sound('Switch 3.ogg', s)
  ui_transition1 = Sound('Wind Bolt 8.ogg', s)
  ui_transition2 = Sound('Wind Bolt 12.ogg', s)
  headbutt1 = Sound('Wind Bolt 14.ogg', s)
  critter1 = Sound('Critters eating 2.ogg', s)
  critter2 = Sound('Crickets Chirping 4.ogg', s)
  critter3 = Sound('Popping bloody Sac 1.ogg', s)
  force1 = Sound('Magical Impact 18.ogg', s)
  error1 = Sound('Error 2.ogg', s)
  coins1 = Sound('Coins 7.ogg', s)
  coins2 = Sound('Coins 8.ogg', s)
  coins3 = Sound('Coins 9.ogg', s)
  shoot1 = Sound('Shooting Projectile (Classic) 11.ogg', s)
  archer1 = Sound('Releasing Bow String 1.ogg', s)
  wizard1 = Sound('Wind Bolt 20.ogg', s)
  swordsman1 = Sound('Heavy sword woosh 1.ogg', s)
  swordsman2 = Sound('Heavy sword woosh 19.ogg', s)
  scout1 = Sound('Throwing Knife (Thrown) 3.ogg', s)
  scout2 = Sound('Throwing Knife (Thrown) 4.ogg', s)
  arrow_hit_wall1 = Sound('Arrow Impact wood 3.ogg', s)
  arrow_hit_wall2 = Sound('Arrow Impact wood 1.ogg', s)
  hit1 = Sound('Player Takes Damage 17.ogg', s)
  hit2 = Sound('Body Head (Headshot) 1.ogg', s)
  hit3 = Sound('Kick 16_1.ogg', s)
  hit4 = Sound('Kick 16_2.ogg', s)
  proj_hit_wall1 = Sound('Player Takes Damage 2.ogg', s)
  enemy_die1 = Sound('Bloody punches 7.ogg', s)
  enemy_die2 = Sound('Bloody punches 10.ogg', s)
  magic_area1 = Sound('Fire bolt 10.ogg', s)
  magic_hit1 = Sound('Shadow Punch 1.ogg', s)
  magic_die1 = Sound('Magical Impact 27.ogg', s)
  knife_hit_wall1 = Sound('Shield Impacts Sword 1.ogg', s)
  blade_hit1 = Sound('Sword impact (Flesh) 2.ogg', s)
  player_hit1 = Sound('Body Fall 2.ogg', s)
  player_hit2 = Sound('Body Fall 18.ogg', s)
  player_hit_wall1 = Sound('Wood Heavy 5.ogg', s)
  pop1 = Sound('Pop sounds 10.ogg', s)
  pop2 = Sound('467951__benzix2__ui-button-click.ogg', s)
  pop3 = Sound('258269__jcallison__mouth-pop.ogg', s)
  confirm1 = Sound('80921__justinbw__buttonchime02up.ogg', s)
  heal1 = Sound('Buff 3.ogg', s)
  spawn1 = Sound('Buff 13.ogg', s)
  buff1 = Sound('Buff 14.ogg', s)
  spawn_mark1 = Sound('Bonus 2.ogg', s)
  spawn_mark2 = Sound('Bonus.ogg', s)
  alert1 = Sound('Click.ogg', s)
  elementor1 = Sound('Wind Bolt 18.ogg', s)
  saboteur_hit1 = Sound('Explosion Flesh_01.ogg', s)
  saboteur_hit2 = Sound('Explosion Flesh_02.ogg', s)
  saboteur1 = Sound('Male Jump 1.ogg', s)
  saboteur2 = Sound('Male Jump 2.ogg', s)
  saboteur3 = Sound('Male Jump 3.ogg', s)
  spark1 = Sound('Spark 1.ogg', s)
  spark2 = Sound('Spark 2.ogg', s)
  spark3 = Sound('Spark 3.ogg', s)
  stormweaver1 = Sound('Buff 8.ogg', s)
  cannoneer1 = Sound('Cannon shots 1.ogg', s)
  cannoneer2 = Sound('Cannon shots 7.ogg', s)
  cannon_hit_wall1 = Sound('Cannon impact sounds (Hitting ship) 4.ogg', s)
  pet1 = Sound('Wolf barks 5.ogg', s)
  turret1 = Sound('Sci Fi Machine Gun 7.ogg', s)
  turret2 = Sound('Sniper Shot_09.ogg', s)
  turret_hit_wall1 = Sound('Concrete 6.ogg', s)
  turret_hit_wall2 = Sound('Concrete 7.ogg', s)
  turret_deploy = Sound('321215__hybrid-v__sci-fi-weapons-deploy.ogg', s)
  rogue_crit1 = Sound('Dagger Stab (Flesh) 4.ogg', s)
  rogue_crit2 = Sound('Sword hits another sword 6.ogg', s)

  song1 = Sound('Kubbi - Ember - 01 Pathfinder.ogg', {tags = {music}})
  song2 = Sound('Kubbi - Ember - 02 Ember.ogg', {tags = {music}})
  song3 = Sound('Kubbi - Ember - 03 Firelight.ogg', {tags = {music}})
  song4 = Sound('Kubbi - Ember - 04 Cascade.ogg', {tags = {music}})
  song5 = Sound('Kubbi - Ember - 05 Compass.ogg', {tags = {music}})
  death_song = Sound('Kubbi - Ember - 09 Formed by Glaciers.ogg', {tags = {music}})

  lock_image = Image('lock')
  speed_booster_elite = Image('speed_booster_elite')
  exploder_elite = Image('exploder_elite')
  swarmer_elite = Image('swarmer_elite')
  forcer_elite = Image('forcer_elite')
  cluster_elite = Image('cluster_elite')
  warrior = Image('warrior')
  ranger = Image('ranger')
  healer = Image('healer')
  mage = Image('mage')
  rogue = Image('rogue')
  nuker = Image('nuker')
  conjurer = Image('conjurer')
  enchanter = Image('enchanter')
  psyker = Image('psyker')
  curser = Image('curser')
  forcer = Image('forcer')
  swarmer = Image('swarmer')
  voider = Image('voider')
  sorcerer = Image('sorcerer')
  mercenary = Image('mercenary')
  explorer = Image('explorer')
  star = Image('star')
  arrow = Image('arrow')
  centipede = Image('centipede')
  ouroboros_technique_r = Image('ouroboros_technique_r')
  ouroboros_technique_l = Image('ouroboros_technique_l')
  amplify = Image('amplify')
  resonance = Image('resonance')
  ballista = Image('ballista')
  call_of_the_void = Image('call_of_the_void')
  crucio = Image('crucio')
  speed_3 = Image('speed_3')
  damage_4 = Image('damage_4')
  shoot_5 = Image('shoot_5')
  death_6 = Image('death_6')
  lasting_7 = Image('lasting_7')
  defensive_stance = Image('defensive_stance')
  offensive_stance = Image('offensive_stance')
  kinetic_bomb = Image('kinetic_bomb')
  porcupine_technique = Image('porcupine_technique')
  last_stand = Image('last_stand')
  seeping = Image('seeping')
  deceleration = Image('deceleration')
  annihilation = Image('annihilation')
  malediction = Image('malediction')
  hextouch = Image('hextouch')
  whispers_of_doom = Image('whispers_of_doom')
  tremor = Image('tremor')
  heavy_impact = Image('heavy_impact')
  fracture = Image('fracture')
  meat_shield = Image('meat_shield')
  hive = Image('hive')
  baneling_burst = Image('baneling_burst')
  blunt_arrow = Image('blunt_arrow')
  explosive_arrow = Image('explosive_arrow')
  divine_machine_arrow = Image('divine_machine_arrow')
  chronomancy = Image('chronomancy')
  awakening = Image('awakening')
  divine_punishment = Image('divine_punishment')
  assassination = Image('assassination')
  flying_daggers = Image('flying_daggers')
  ultimatum = Image('ultimatum')
  magnify = Image('magnify')
  echo_barrage = Image('echo_barrage')
  unleash = Image('unleash')
  reinforce = Image('reinforce')
  payback = Image('payback')
  enchanted = Image('enchanted')
  freezing_field = Image('freezing_field')
  burning_field = Image('burning_field')
  gravity_field = Image('gravity_field')
  magnetism = Image('magnetism')
  insurance = Image('insurance')
  dividends = Image('dividends')
  berserking = Image('berserking')
  unwavering_stance = Image('unwavering_stance')
  unrelenting_stance = Image('unrelenting_stance')
  blessing = Image('blessing')
  haste = Image('haste')
  divine_barrage = Image('divine_barrage')
  orbitism = Image('orbitism')
  psyker_orbs = Image('psyker_orbs')
  psychosense = Image('psychosense')
  psychosink = Image('psychosink')
  rearm = Image('rearm')
  taunt = Image('taunt')
  construct_instability = Image('construct_instability')
  intimidation = Image('intimidation')
  vulnerability = Image('vulnerability')
  temporal_chains = Image('temporal_chains')
  ceremonial_dagger = Image('ceremonial_dagger')
  homing_barrage = Image('homing_barrage')
  critical_strike = Image('critical_strike')
  noxious_strike = Image('noxious_strike')
  infesting_strike = Image('infesting_strike')
  kinetic_strike = Image('kinetic_strike')
  burning_strike = Image('burning_strike')
  lucky_strike = Image('lucky_strike')
  healing_strike = Image('healing_strike')
  stunning_strike = Image('stunning_strike')
  silencing_strike = Image('silencing_strike')
  warping_shots = Image('warping_shots')
  culling_strike = Image('culling_strike')
  lightning_strike = Image('lightning_strike')
  psycholeak = Image('psycholeak')
  divine_blessing = Image('divine_blessing')
  hardening = Image('hardening')

  class_colors = {
    ['warrior'] = yellow[0],
    ['ranger'] = green[0],
    ['healer'] = green[0],
    ['conjurer'] = orange[0],
    ['mage'] = blue[0],
    ['nuker'] = red[0],
    ['rogue'] = red[0],
    ['enchanter'] = blue[0],
    ['psyker'] = fg[0],
    ['curser'] = purple[0],
    ['forcer'] = yellow[0],
    ['swarmer'] = orange[0],
    ['voider'] = purple[0],
    ['sorcerer'] = blue2[0],
    ['mercenary'] = yellow2[0],
    ['explorer'] = fg[0],
  }

  class_color_strings = {
    ['warrior'] = 'yellow',
    ['ranger'] = 'green',
    ['healer'] = 'green',
    ['conjurer'] = 'orange',
    ['mage'] = 'blue',
    ['nuker'] = 'red',
    ['rogue'] = 'red',
    ['enchanter'] = 'blue',
    ['psyker'] = 'fg',
    ['curser'] = 'purple',
    ['forcer'] = 'yellow',
    ['swarmer'] = 'orange',
    ['voider'] = 'purple',
    ['sorcerer'] = 'blue2',
    ['mercenary'] = 'yellow2',
    ['explorer'] = 'fg',
  }

  character_colors = {
    ['vagrant'] = fg[0],
    ['swordsman'] = yellow[0],
    ['wizard'] = blue[0],
    ['magician'] = blue[0],
    ['archer'] = green[0],
    ['scout'] = red[0],
    ['cleric'] = green[0],
    ['outlaw'] = red[0],
    ['blade'] = yellow[0],
    ['elementor'] = blue[0],
    ['saboteur'] = orange[0],
    ['bomber'] = orange[0],
    ['stormweaver'] = blue[0],
    ['sage'] = purple[0],
    ['squire'] = yellow[0],
    ['cannoneer'] = orange[0],
    ['dual_gunner'] = green[0],
    ['hunter'] = green[0],
    ['sentry'] = green[0],
    ['chronomancer'] = blue[0],
    ['spellblade'] = blue[0],
    ['psykeeper'] = fg[0],
    ['engineer'] = orange[0],
    ['plague_doctor'] = purple[0],
    ['barbarian'] = yellow[0],
    ['juggernaut'] = yellow[0],
    ['lich'] = blue[0],
    ['cryomancer'] = blue[0],
    ['pyromancer'] = red[0],
    ['corruptor'] = orange[0],
    ['beastmaster'] = red[0],
    ['launcher'] = yellow[0],
    ['jester'] = red[0],
    ['assassin'] = purple[0],
    ['host'] = orange[0],
    ['carver'] = green[0],
    ['bane'] = purple[0],
    ['psykino'] = fg[0],
    ['barrager'] = green[0],
    ['highlander'] = yellow[0],
    ['fairy'] = green[0],
    ['priest'] = green[0],
    ['infestor'] = orange[0],
    ['flagellant'] = fg[0],
    ['arcanist'] = blue2[0],
    ['illusionist'] = blue2[0],
    ['artificer'] = blue2[0],
    ['witch'] = purple[0],
    ['silencer'] = blue2[0],
    ['vulcanist'] = red[0],
    ['warden'] = yellow[0],
    ['psychic'] = fg[0],
    ['miner'] = yellow2[0],
    ['merchant'] = yellow2[0],
    ['usurer'] = purple[0],
    ['gambler'] = yellow2[0],
    ['thief'] = red[0],
  }

  character_color_strings = {
    ['vagrant'] = 'fg',
    ['swordsman'] = 'yellow',
    ['wizard'] = 'blue',
    ['magician'] = 'blue',
    ['archer'] = 'green',
    ['scout'] = 'red',
    ['cleric'] = 'green',
    ['outlaw'] = 'red',
    ['blade'] = 'yellow',
    ['elementor'] = 'blue',
    ['saboteur'] = 'orange',
    ['bomber'] = 'orange',
    ['stormweaver'] = 'blue',
    ['sage'] = 'purple',
    ['squire'] = 'yellow',
    ['cannoneer'] = 'orange',
    ['dual_gunner'] = 'green',
    ['hunter'] = 'green',
    ['sentry'] = 'green',
    ['chronomancer'] = 'blue',
    ['spellblade'] = 'blue',
    ['psykeeper'] = 'fg',
    ['engineer'] = 'orange',
    ['plague_doctor'] = 'purple',
    ['barbarian'] = 'yellow',
    ['juggernaut'] = 'yellow',
    ['lich'] = 'blue',
    ['cryomancer'] = 'blue',
    ['pyromancer'] = 'red',
    ['corruptor'] = 'orange',
    ['beastmaster'] = 'red',
    ['launcher'] = 'yellow',
    ['jester'] = 'red',
    ['assassin'] = 'purple',
    ['host'] = 'orange',
    ['carver'] = 'green',
    ['bane'] = 'purple',
    ['psykino'] = 'fg',
    ['barrager'] = 'green',
    ['highlander'] = 'yellow',
    ['fairy'] = 'green',
    ['priest'] = 'green',
    ['infestor'] = 'orange',
    ['flagellant'] = 'fg',
    ['arcanist'] = 'blue2',
    ['illusionist'] = 'blue2',
    ['artificer'] = 'blue2',
    ['witch'] = 'purple',
    ['silencer'] = 'blue2',
    ['vulcanist'] = 'red',
    ['warden'] = 'yellow',
    ['psychic'] = 'fg',
    ['miner'] = 'yellow2',
    ['merchant'] = 'yellow2',
    ['usurer'] = 'purple',
    ['gambler'] = 'yellow2',
    ['thief'] = 'red',
  }

  character_classes = {
    ['vagrant'] = {'explorer', 'psyker'},
    ['swordsman'] = {'warrior'},
    ['wizard'] = {'mage', 'nuker'},
    ['magician'] = {'mage'},
    ['archer'] = {'ranger'},
    ['scout'] = {'rogue'},
    ['cleric'] = {'healer'},
    ['outlaw'] = {'warrior', 'rogue'},
    ['blade'] = {'warrior', 'nuker'},
    ['elementor'] = {'mage', 'nuker'},
    -- ['saboteur'] = {'rogue', 'conjurer', 'nuker'},
    ['bomber'] = {'nuker', 'conjurer'},
    ['stormweaver'] = {'enchanter'},
    ['sage'] = {'nuker', 'forcer'},
    ['squire'] = {'warrior', 'enchanter'},
    ['cannoneer'] = {'ranger', 'nuker'},
    ['dual_gunner'] = {'ranger', 'rogue'},
    -- ['hunter'] = {'ranger', 'conjurer', 'forcer'},
    ['sentry'] = {'ranger', 'conjurer'},
    ['chronomancer'] = {'mage', 'enchanter'},
    ['spellblade'] = {'mage', 'rogue'},
    ['psykeeper'] = {'healer', 'psyker'},
    ['engineer'] = {'conjurer'},
    ['plague_doctor'] = {'nuker', 'voider'},
    ['barbarian'] = {'curser', 'warrior'},
    ['juggernaut'] = {'forcer', 'warrior'},
    ['lich'] = {'mage'},
    ['cryomancer'] = {'mage', 'voider'},
    ['pyromancer'] = {'mage', 'nuker', 'voider'},
    ['corruptor'] = {'ranger', 'swarmer'},
    ['beastmaster'] = {'rogue', 'swarmer'},
    ['launcher'] = {'curser', 'forcer'},
    ['jester'] = {'curser', 'rogue'},
    ['assassin'] = {'rogue', 'voider'},
    ['host'] = {'swarmer'},
    ['carver'] = {'conjurer', 'healer'},
    ['bane'] = {'curser', 'voider'},
    ['psykino'] = {'mage', 'psyker', 'forcer'},
    ['barrager'] = {'ranger', 'forcer'},
    ['highlander'] = {'warrior'},
    ['fairy'] = {'enchanter', 'healer'},
    ['priest'] = {'healer'},
    ['infestor'] = {'curser', 'swarmer'},
    ['flagellant'] = {'psyker', 'enchanter'},
    ['arcanist'] = {'sorcerer'},
    -- ['illusionist'] = {'sorcerer', 'conjurer'},
    ['artificer'] = {'sorcerer', 'conjurer'},
    ['witch'] = {'sorcerer', 'voider'},
    ['silencer'] = {'sorcerer', 'curser'},
    ['vulcanist'] = {'sorcerer', 'nuker'},
    ['warden'] = {'sorcerer', 'forcer'},
    ['psychic'] = {'sorcerer', 'psyker'},
    ['miner'] = {'mercenary'},
    ['merchant'] = {'mercenary'},
    ['usurer'] = {'curser', 'mercenary', 'voider'},
    ['gambler'] = {'mercenary', 'sorcerer'},
    ['thief'] = {'rogue', 'mercenary'},
  }

  get_character_stat_string = function(character, level)
    local group = Group():set_as_physics_world(32, 0, 0, {'player', 'enemy', 'projectile', 'enemy_projectile'})
    local player = Player{group = group, leader = true, character = character, level = level, follower_index = 1}
    player:update(0)
    return T('ui.stat_line', player.max_hp, player.dmg, math.round(player.aspd_m, 2),
      math.round(player.area_dmg_m*player.area_size_m, 2), math.round(player.def, 2), math.round(player.v, 2))
  end

  get_character_stat = function(character, level, stat)
    local group = Group():set_as_physics_world(32, 0, 0, {'player', 'enemy', 'projectile', 'enemy_projectile'})
    local player = Player{group = group, leader = true, character = character, level = level, follower_index = 1}
    player:update(0)
    return math.round(player[stat], 2)
  end

  character_stats = {
    ['vagrant'] = function(lvl) return get_character_stat_string('vagrant', lvl) end,
    ['swordsman'] = function(lvl) return get_character_stat_string('swordsman', lvl) end, 
    ['wizard'] = function(lvl) return get_character_stat_string('wizard', lvl) end, 
    ['magician'] = function(lvl) return get_character_stat_string('magician', lvl) end, 
    ['archer'] = function(lvl) return get_character_stat_string('archer', lvl) end, 
    ['scout'] = function(lvl) return get_character_stat_string('scout', lvl) end, 
    ['cleric'] = function(lvl) return get_character_stat_string('cleric', lvl) end, 
    ['outlaw'] = function(lvl) return get_character_stat_string('outlaw', lvl) end, 
    ['blade'] = function(lvl) return get_character_stat_string('blade', lvl) end, 
    ['elementor'] = function(lvl) return get_character_stat_string('elementor', lvl) end, 
    ['saboteur'] = function(lvl) return get_character_stat_string('saboteur', lvl) end, 
    ['bomber'] = function(lvl) return get_character_stat_string('bomber', lvl) end, 
    ['stormweaver'] = function(lvl) return get_character_stat_string('stormweaver', lvl) end, 
    ['sage'] = function(lvl) return get_character_stat_string('sage', lvl) end, 
    ['squire'] = function(lvl) return get_character_stat_string('squire', lvl) end, 
    ['cannoneer'] = function(lvl) return get_character_stat_string('cannoneer', lvl) end, 
    ['dual_gunner'] = function(lvl) return get_character_stat_string('dual_gunner', lvl) end, 
    ['hunter'] = function(lvl) return get_character_stat_string('hunter', lvl) end, 
    ['sentry'] = function(lvl) return get_character_stat_string('sentry', lvl) end, 
    ['chronomancer'] = function(lvl) return get_character_stat_string('chronomancer', lvl) end, 
    ['spellblade'] = function(lvl) return get_character_stat_string('spellblade', lvl) end, 
    ['psykeeper'] = function(lvl) return get_character_stat_string('psykeeper', lvl) end, 
    ['engineer'] = function(lvl) return get_character_stat_string('engineer', lvl) end, 
    ['plague_doctor'] = function(lvl) return get_character_stat_string('plague_doctor', lvl) end,
    ['barbarian'] = function(lvl) return get_character_stat_string('barbarian', lvl) end,
    ['juggernaut'] = function(lvl) return get_character_stat_string('juggernaut', lvl) end,
    ['lich'] = function(lvl) return get_character_stat_string('lich', lvl) end,
    ['cryomancer'] = function(lvl) return get_character_stat_string('cryomancer', lvl) end,
    ['pyromancer'] = function(lvl) return get_character_stat_string('pyromancer', lvl) end,
    ['corruptor'] = function(lvl) return get_character_stat_string('corruptor', lvl) end,
    ['beastmaster'] = function(lvl) return get_character_stat_string('beastmaster', lvl) end,
    ['launcher'] = function(lvl) return get_character_stat_string('launcher', lvl) end,
    ['jester'] = function(lvl) return get_character_stat_string('jester', lvl) end,
    ['assassin'] = function(lvl) return get_character_stat_string('assassin', lvl) end,
    ['host'] = function(lvl) return get_character_stat_string('host', lvl) end,
    ['carver'] = function(lvl) return get_character_stat_string('carver', lvl) end,
    ['bane'] = function(lvl) return get_character_stat_string('bane', lvl) end,
    ['psykino'] = function(lvl) return get_character_stat_string('psykino', lvl) end,
    ['barrager'] = function(lvl) return get_character_stat_string('barrager', lvl) end,
    ['highlander'] = function(lvl) return get_character_stat_string('highlander', lvl) end,
    ['fairy'] = function(lvl) return get_character_stat_string('fairy', lvl) end,
    ['priest'] = function(lvl) return get_character_stat_string('priest', lvl) end,
    ['infestor'] = function(lvl) return get_character_stat_string('infestor', lvl) end,
    ['flagellant'] = function(lvl) return get_character_stat_string('flagellant', lvl) end,
    ['arcanist'] = function(lvl) return get_character_stat_string('arcanist', lvl) end,
    ['illusionist'] = function(lvl) return get_character_stat_string('illusionist', lvl) end,
    ['artificer'] = function(lvl) return get_character_stat_string('artificer', lvl) end,
    ['witch'] = function(lvl) return get_character_stat_string('witch', lvl) end,
    ['silencer'] = function(lvl) return get_character_stat_string('silencer', lvl) end,
    ['vulcanist'] = function(lvl) return get_character_stat_string('vulcanist', lvl) end,
    ['warden'] = function(lvl) return get_character_stat_string('warden', lvl) end,
    ['psychic'] = function(lvl) return get_character_stat_string('psychic', lvl) end,
    ['miner'] = function(lvl) return get_character_stat_string('miner', lvl) end,
    ['merchant'] = function(lvl) return get_character_stat_string('merchant', lvl) end,
    ['usurer'] = function(lvl) return get_character_stat_string('usurer', lvl) end,
    ['gambler'] = function(lvl) return get_character_stat_string('gambler', lvl) end,
    ['thief'] = function(lvl) return get_character_stat_string('thief', lvl) end,
  }

  class_stat_multipliers = {
    ['ranger'] = {hp = 1, dmg = 1.2, aspd = 1.5, area_dmg = 1, area_size = 1, def = 0.9, mvspd = 1.2},
    ['warrior'] = {hp = 1.4, dmg = 1.1, aspd = 0.9, area_dmg = 1, area_size = 1, def = 1.25, mvspd = 0.9},
    ['mage'] = {hp = 0.6, dmg = 1.4, aspd = 1, area_dmg = 1.25, area_size = 1.2, def = 0.75, mvspd = 1},
    ['rogue'] = {hp = 0.8, dmg = 1.3, aspd = 1.1, area_dmg = 0.6, area_size = 0.6, def = 0.8, mvspd = 1.4},
    ['healer'] = {hp = 1.2, dmg = 1, aspd = 0.5, area_dmg = 1, area_size = 1, def = 1.2, mvspd = 1},
    ['enchanter'] = {hp = 1.2, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1.2, mvspd = 1.2},
    ['nuker'] = {hp = 0.9, dmg = 1, aspd = 0.75, area_dmg = 1.5, area_size = 1.5, def = 1, mvspd = 1},
    ['conjurer'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1},
    ['psyker'] = {hp = 1.5, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 0.5, mvspd = 1},
    ['curser'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 0.75, mvspd = 1},
    ['forcer'] = {hp = 1.25, dmg = 1.1, aspd = 0.9, area_dmg = 0.75, area_size = 0.75, def = 1.2, mvspd = 1},
    ['swarmer'] = {hp = 1.2, dmg = 1, aspd = 1.25, area_dmg = 1, area_size = 1, def = 0.75, mvspd = 0.75},
    ['voider'] = {hp = 0.75, dmg = 1.3, aspd = 1, area_dmg = 0.8, area_size = 0.75, def = 0.6, mvspd = 0.8},
    ['sorcerer'] = {hp = 0.8, dmg = 1.3, aspd = 1, area_dmg = 1.2, area_size = 1, def = 0.8, mvspd = 1},
    ['mercenary'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1},
    ['explorer'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1.25},
    ['seeker'] = {hp = 0.5, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 0.3},
    ['mini_boss'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 0.3},
    ['enemy_critter'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 0.5},
    ['saboteur'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1.4},
  }

  tier_to_characters = {
    [1] = {'vagrant', 'swordsman', 'magician', 'archer', 'scout', 'cleric', 'arcanist', 'merchant'},
    [2] = {'wizard', 'bomber', 'sage', 'squire', 'dual_gunner', 'sentry', 'chronomancer', 'barbarian', 'cryomancer', 'beastmaster', 'jester', 'carver', 'psychic', 'witch', 'silencer', 'outlaw', 'miner'},
    [3] = {'elementor', 'stormweaver', 'spellblade', 'psykeeper', 'engineer', 'juggernaut', 'pyromancer', 'host', 'assassin', 'bane', 'barrager', 'infestor', 'flagellant', 'artificer', 'usurer', 'gambler'},
    [4] = {'priest', 'highlander', 'psykino', 'fairy', 'blade', 'plague_doctor', 'cannoneer', 'vulcanist', 'warden', 'corruptor', 'thief'},
  }

  non_attacking_characters = {'cleric', 'stormweaver', 'squire', 'chronomancer', 'sage', 'psykeeper', 'bane', 'carver', 'fairy', 'priest', 'flagellant', 'merchant', 'miner'}
  non_cooldown_characters = {'squire', 'chronomancer', 'psykeeper', 'merchant', 'miner'}

  character_tiers = {
    ['vagrant'] = 1,
    ['swordsman'] = 1,
    ['magician'] = 1,
    ['archer'] = 1,
    ['scout'] = 1,
    ['cleric'] = 1,
    ['outlaw'] = 2,
    ['blade'] = 4,
    ['elementor'] = 3,
    -- ['saboteur'] = 2,
    ['bomber'] = 2,
    ['wizard'] = 2,
    ['stormweaver'] = 3,
    ['sage'] = 2,
    ['squire'] = 2,
    ['cannoneer'] = 4,
    ['dual_gunner'] = 2,
    -- ['hunter'] = 2,
    ['sentry'] = 2,
    ['chronomancer'] = 2,
    ['spellblade'] = 3,
    ['psykeeper'] = 3,
    ['engineer'] = 3,
    ['plague_doctor'] = 4,
    ['barbarian'] = 2,
    ['juggernaut'] = 3,
    -- ['lich'] = 4,
    ['cryomancer'] = 2,
    ['pyromancer'] = 3,
    ['corruptor'] = 4,
    ['beastmaster'] = 2,
    -- ['launcher'] = 2,
    ['jester'] = 2,
    ['assassin'] = 3,
    ['host'] = 3,
    ['carver'] = 2,
    ['bane'] = 3,
    ['psykino'] = 4,
    ['barrager'] = 3,
    ['highlander'] = 4,
    ['fairy'] = 4,
    ['priest'] = 4,
    ['infestor'] = 3,
    ['flagellant'] = 3,
    ['arcanist'] = 1,
    -- ['illusionist'] = 3,
    ['artificer'] = 3,
    ['witch'] = 2,
    ['silencer'] = 2,
    ['vulcanist'] = 4,
    ['warden'] = 4,
    ['psychic'] = 2,
    ['miner'] = 2,
    ['merchant'] = 1,
    ['usurer'] = 3,
    ['gambler'] = 3,
    ['thief'] = 4,
  }

  launches_projectiles = function(character)
    local classes = {'vagrant', 'archer', 'scout', 'outlaw', 'blade', 'wizard', 'cannoneer', 'dual_gunner', 'hunter', 'spellblade', 'engineer', 'corruptor', 'beastmaster', 'jester', 'assassin', 'barrager', 
      'arcanist', 'illusionist', 'artificer', 'miner', 'thief', 'sentry'}
    return table.any(classes, function(v) return v == character end)
  end

  get_number_of_units_per_class = function(units)
    local rangers = 0
    local warriors = 0
    local healers = 0
    local mages = 0
    local nukers = 0
    local conjurers = 0
    local rogues = 0
    local enchanters = 0
    local psykers = 0
    local cursers = 0
    local forcers = 0
    local swarmers = 0
    local voiders = 0
    local sorcerers = 0
    local mercenaries = 0
    local explorers = 0
    for _, unit in ipairs(units) do
      for _, unit_class in ipairs(character_classes[unit.character]) do
        if unit_class == 'ranger' then rangers = rangers + 1 end
        if unit_class == 'warrior' then warriors = warriors + 1 end
        if unit_class == 'healer' then healers = healers + 1 end
        if unit_class == 'mage' then mages = mages + 1 end
        if unit_class == 'nuker' then nukers = nukers + 1 end
        if unit_class == 'conjurer' then conjurers = conjurers + 1 end
        if unit_class == 'rogue' then rogues = rogues + 1 end
        if unit_class == 'enchanter' then enchanters = enchanters + 1 end
        if unit_class == 'psyker' then psykers = psykers + 1 end
        if unit_class == 'curser' then cursers = cursers + 1 end
        if unit_class == 'forcer' then forcers = forcers + 1 end
        if unit_class == 'swarmer' then swarmers = swarmers + 1 end
        if unit_class == 'voider' then voiders = voiders + 1 end
        if unit_class == 'sorcerer' then sorcerers = sorcerers + 1 end
        if unit_class == 'mercenary' then mercenaries = mercenaries + 1 end
        if unit_class == 'explorer' then explorers = explorers + 1 end
      end
    end
    return {ranger = rangers, warrior = warriors, healer = healers, mage = mages, nuker = nukers, conjurer = conjurers, rogue = rogues,
      enchanter = enchanters, psyker = psykers, curser = cursers, forcer = forcers, swarmer = swarmers, voider = voiders, sorcerer = sorcerers, mercenary = mercenaries, explorer = explorers}
  end

  get_class_levels = function(units)
    local units_per_class = get_number_of_units_per_class(units)
    local units_to_class_level = function(number_of_units, class)
      if class == 'ranger' or class == 'warrior' or class == 'mage' or class == 'nuker' or class == 'rogue' then
        if number_of_units >= 6 then return 2
        elseif number_of_units >= 3 then return 1
        else return 0 end
      elseif class == 'healer' or class == 'conjurer' or class == 'enchanter' or class == 'curser' or class == 'forcer' or class == 'swarmer' or class == 'voider' or class == 'mercenary' or class == 'psyker' then
        if number_of_units >= 4 then return 2
        elseif number_of_units >= 2 then return 1
        else return 0 end
      elseif class == 'sorcerer' then
        if number_of_units >= 6 then return 3
        elseif number_of_units >= 4 then return 2
        elseif number_of_units >= 2 then return 1
        else return 0 end
      elseif class == 'explorer' then
        if number_of_units >= 1 then return 1
        else return 0 end
      end
    end
    return {
      ranger = units_to_class_level(units_per_class.ranger, 'ranger'),
      warrior = units_to_class_level(units_per_class.warrior, 'warrior'),
      mage = units_to_class_level(units_per_class.mage, 'mage'),
      nuker = units_to_class_level(units_per_class.nuker, 'nuker'),
      rogue = units_to_class_level(units_per_class.rogue, 'rogue'),
      healer = units_to_class_level(units_per_class.healer, 'healer'),
      conjurer = units_to_class_level(units_per_class.conjurer, 'conjurer'),
      enchanter = units_to_class_level(units_per_class.enchanter, 'enchanter'),
      psyker = units_to_class_level(units_per_class.psyker, 'psyker'),
      curser = units_to_class_level(units_per_class.curser, 'curser'),
      forcer = units_to_class_level(units_per_class.forcer, 'forcer'),
      swarmer = units_to_class_level(units_per_class.swarmer, 'swarmer'),
      voider = units_to_class_level(units_per_class.voider, 'voider'),
      sorcerer = units_to_class_level(units_per_class.sorcerer, 'sorcerer'),
      mercenary = units_to_class_level(units_per_class.mercenary, 'mercenary'),
      explorer = units_to_class_level(units_per_class.explorer, 'explorer'),
    }
  end

  get_classes = function(units)
    local classes = {}
    for _, unit in ipairs(units) do
      table.insert(classes, table.copy(character_classes[unit.character]))
    end
    return table.unify(table.flatten(classes))
  end

  class_set_numbers = {
    ['ranger'] = function(units) return 3, 6, nil, get_number_of_units_per_class(units).ranger end,
    ['warrior'] = function(units) return 3, 6, nil, get_number_of_units_per_class(units).warrior end,
    ['mage'] = function(units) return 3, 6, nil, get_number_of_units_per_class(units).mage end,
    ['nuker'] = function(units) return 3, 6, nil, get_number_of_units_per_class(units).nuker end,
    ['rogue'] = function(units) return 3, 6, nil, get_number_of_units_per_class(units).rogue end,
    ['healer'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).healer end,
    ['conjurer'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).conjurer end,
    ['enchanter'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).enchanter end,
    ['psyker'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).psyker end,
    ['curser'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).curser end,
    ['forcer'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).forcer end,
    ['swarmer'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).swarmer end,
    ['voider'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).voider end,
    ['sorcerer'] = function(units) return 2, 4, 6, get_number_of_units_per_class(units).sorcerer end,
    ['mercenary'] = function(units) return 2, 4, nil, get_number_of_units_per_class(units).mercenary end,
    ['explorer'] = function(units) return 1, 1, nil, get_number_of_units_per_class(units).explorer end,
  }

  level_to_tier_weights = {
    [1] = {90, 10, 0, 0},
    [2] = {80, 15, 5, 0},
    [3] = {75, 20, 5, 0},
    [4] = {70, 20, 10, 0},
    [5] = {70, 20, 10, 0},
    [6] = {65, 25, 10, 0},
    [7] = {60, 25, 15, 0},
    [8] = {55, 25, 15, 5},
    [9] = {50, 30, 15, 5},
    [10] = {50, 30, 15, 5},
    [11] = {45, 30, 20, 5},
    [12] = {40, 30, 20, 10},
    [13] = {35, 30, 25, 10},
    [14] = {30, 30, 25, 15},
    [15] = {25, 30, 30, 15},
    [16] = {25, 25, 30, 20},
    [17] = {20, 25, 35, 20},
    [18] = {15, 25, 35, 25},
    [19] = {10, 25, 40, 25},
    [20] = {5, 25, 40, 30},
    [21] = {0, 25, 40, 35},
    [22] = {0, 20, 40, 40},
    [23] = {0, 20, 35, 45},
    [24] = {0, 10, 30, 60},
    [25] = {0, 0, 0, 100},
  }

  level_to_gold_gained = {
    [1] = {3, 3},
    [2] = {3, 3},
    [3] = {5, 6},
    [4] = {4, 5},
    [5] = {5, 8},
    [6] = {8, 10},
    [7] = {8, 10}, 
    [8] = {12, 14},
    [9] = {14, 18},
    [10] = {10, 13},
    [11] = {12, 15},
    [12] = {18, 20},
    [13] = {10, 14},
    [14] = {12, 16},
    [15] = {14, 18},
    [16] = {12, 12},
    [17] = {12, 12},
    [18] = {20, 24}, 
    [19] = {8, 12},
    [20] = {10, 14}, 
    [21] = {20, 28},
    [22] = {32, 32},
    [23] = {36, 36},
    [24] = {48, 48},
    [25] = {100, 100},
  }

  local k = 1
  for i = 26, 5000 do
    local n = i % 25
    if n == 0 then
      n = 25
      k = k + 1
    end
    level_to_gold_gained[i] = {level_to_gold_gained[n][1]*k, level_to_gold_gained[n][2]*k}
  end

  level_to_elite_spawn_weights = {
    [1] = {0},
    [2] = {4, 2},
    [3] = {10},
    [4] = {4, 4},
    [5] = {4, 3, 2},
    [6] = {12},
    [7] = {5, 3, 2},
    [8] = {6, 3, 3, 3},
    [9] = {14},
    [10] = {8, 4},
    [11] = {8, 6, 2},
    [12] = {16},
    [13] = {8, 8},
    [14] = {12, 6},
    [15] = {18},
    [16] = {10, 6, 4},
    [17] = {6, 5, 4, 3},
    [18] = {18},
    [19] = {10, 6},
    [20] = {8, 6, 2},
    [21] = {22},
    [22] = {10, 8, 4},
    [23] = {20, 5, 5},
    [24] = {30},
    [25] = {5, 5, 5, 5, 5, 5},
  }

  local k = 1
  local l = 0.2
  for i = 26, 5000 do
    local n = i % 25
    if n == 0 then
      n = 25
      k = k + 1
      l = l*2
    end
    local a, b, c, d, e, f = unpack(level_to_elite_spawn_weights[n])
    a = (a or 0) + (a or 0)*l
    b = (b or 0) + (b or 0)*l
    c = (c or 0) + (c or 0)*l
    d = (d or 0) + (d or 0)*l
    e = (e or 0) + (e or 0)*l
    f = (f or 0) + (f or 0)*l
    level_to_elite_spawn_weights[i] = {a, b, c, d, e, f}
  end

  level_to_boss = {
    [6] = 'speed_booster',
    [12] = 'exploder',
    [18] = 'swarmer',
    [24] = 'forcer',
    [25] = 'randomizer',
  }

  local bosses = {'speed_booster', 'exploder', 'swarmer', 'forcer', 'randomizer'}
  level_to_boss[31] = 'speed_booster'
  level_to_boss[37] = 'exploder'
  level_to_boss[43] = 'swarmer'
  level_to_boss[49] = 'forcer'
  level_to_boss[50] = 'randomizer'
  local i = 31
  local k = 1
  while i < 5000 do
    level_to_boss[i] = bosses[k]
    k = k + 1
    if k == 5 then i = i + 1 else i = i + 6 end
    if k == 6 then k = 1 end
  end

  level_to_elite_spawn_types = {
    [1] = {'speed_booster'},
    [2] = {'speed_booster', 'shooter'},
    [3] = {'speed_booster'},
    [4] = {'speed_booster', 'exploder'},
    [5] = {'speed_booster', 'exploder', 'shooter'},
    [6] = {'speed_booster'},
    [7] = {'speed_booster', 'exploder', 'headbutter'},
    [8] = {'speed_booster', 'exploder', 'headbutter', 'shooter'},
    [9] = {'shooter'},
    [10] = {'exploder', 'headbutter'},
    [11] = {'exploder', 'headbutter', 'tank'},
    [12] = {'exploder'},
    [13] = {'speed_booster', 'shooter'},
    [14] = {'speed_booster', 'spawner'},
    [15] = {'shooter'},
    [16] = {'speed_booster', 'exploder', 'spawner'},
    [17] = {'speed_booster', 'exploder', 'spawner', 'shooter'},
    [18] = {'spawner'},
    [19] = {'headbutter', 'tank'},
    [20] = {'speed_booster', 'tank', 'spawner'},
    [21] = {'headbutter'},
    [22] = {'speed_booster', 'headbutter', 'tank'},
    [23] = {'headbutter', 'tank', 'shooter'},
    [24] = {'tank'},
    [25] = {'speed_booster', 'exploder', 'headbutter', 'tank', 'shooter', 'spawner'},
  }

  for i = 26, 5000 do
    local n = i % 25
    if n == 0 then
      n = 25
    end
    level_to_elite_spawn_types[i] = level_to_elite_spawn_types[n]
  end

  level_to_shop_odds = {
    [1] = {70, 20, 10, 0},
    [2] = {50, 30, 15, 5},
    [3] = {25, 45, 20, 10},
    [4] = {10, 25, 45, 20},
    [5] = {5, 15, 30, 50},
  }

  get_shop_odds = function(lvl, tier)
    if lvl == 1 then
      if tier == 1 then
        return 70
      elseif tier == 2 then
        return 20
      elseif tier == 3 then
        return 10
      elseif tier == 4 then
        return 0
      end
    elseif lvl == 2 then
      if tier == 1 then
        return 50
      elseif tier == 2 then
        return 30
      elseif tier == 3 then
        return 15
      elseif tier == 4 then
        return 5
      end
    elseif lvl == 3 then
      if tier == 1 then
        return 25
      elseif tier == 2 then
        return 45
      elseif tier == 3 then
        return 20
      elseif tier == 4 then
        return 10
      end
    elseif lvl == 4 then
      if tier == 1 then
        return 10
      elseif tier == 2 then
        return 25
      elseif tier == 3 then
        return 45
      elseif tier == 4 then
        return 20
      end
    elseif lvl == 5 then
      if tier == 1 then
        return 5
      elseif tier == 2 then
        return 15
      elseif tier == 3 then
        return 30
      elseif tier == 4 then
        return 50
      end
    end
  end

  unlevellable_items = {
    'speed_3', 'damage_4', 'shoot_5', 'death_6', 'lasting_7', 'kinetic_bomb', 'porcupine_technique', 'last_stand', 'annihilation', 
    'tremor', 'heavy_impact', 'fracture', 'meat_shield', 'divine_punishment', 'unleash', 'freezing_field', 'burning_field', 'gravity_field',
    'magnetism', 'insurance', 'dividends', 'haste', 'rearm', 'ceremonial_dagger', 'burning_strike', 'lucky_strike', 'healing_strike', 'psycholeak', 'divine_blessing', 'hardening',
  }

  steam.userStats.requestCurrentStats()
  new_game_plus = state.new_game_plus or 0
  if not state.new_game_plus then state.new_game_plus = new_game_plus end
  current_new_game_plus = state.current_new_game_plus or new_game_plus
  if not state.current_new_game_plus then state.current_new_game_plus = current_new_game_plus end
  max_units = math.clamp(7 + current_new_game_plus, 7, 12)

  main_song_instance = _G[random:table{'song1', 'song2', 'song3', 'song4', 'song5'}]:play{volume = 0.5}
  main = Main()

  main:add(MainMenu'mainmenu')
  main:go_to('mainmenu')

  --[[
  main:add(BuyScreen'buy_screen')
  main:go_to('buy_screen', run.level or 1, run.units or {}, passives, run.shop_level or 1, run.shop_xp or 0)
  -- main:go_to('buy_screen', 7, run.units or {}, {'unleash'})
  ]]--
  
  --[[
  gold = 10
  run_passive_pool = {
    'centipede', 'ouroboros_technique_r', 'ouroboros_technique_l', 'amplify', 'resonance', 'ballista', 'call_of_the_void', 'crucio', 'speed_3', 'damage_4', 'shoot_5', 'death_6', 'lasting_7',
    'defensive_stance', 'offensive_stance', 'kinetic_bomb', 'porcupine_technique', 'last_stand', 'seeping', 'deceleration', 'annihilation', 'malediction', 'hextouch', 'whispers_of_doom',
    'tremor', 'heavy_impact', 'fracture', 'meat_shield', 'hive', 'baneling_burst', 'blunt_arrow', 'explosive_arrow', 'divine_machine_arrow', 'chronomancy', 'awakening', 'divine_punishment',
    'assassination', 'flying_daggers', 'ultimatum', 'magnify', 'echo_barrage', 'unleash', 'reinforce', 'payback', 'enchanted', 'freezing_field', 'burning_field', 'gravity_field', 'magnetism',
    'insurance', 'dividends', 'berserking', 'unwavering_stance', 'unrelenting_stance', 'blessing', 'haste', 'divine_barrage', 'orbitism', 'psyker_orbs', 'psychosink', 'rearm', 'taunt', 'construct_instability',
    'intimidation', 'vulnerability', 'temporal_chains', 'ceremonial_dagger', 'homing_barrage', 'critical_strike', 'noxious_strike', 'infesting_strike', 'burning_strike', 'lucky_strike', 'healing_strike', 'stunning_strike',
    'silencing_strike', 'culling_strike', 'lightning_strike', 'psycholeak', 'divine_blessing', 'hardening', 'kinetic_strike',
  }
  main:add(Arena'arena')
  main:go_to('arena', 21, 0, {
    {character = 'magician', level = 3},
  }, {
    {passive = 'awakening', level = 3},
  })
  ]]--

  --[[
  main:add(Media'media')
  main:go_to('media')
  ]]--

  trigger:every(2, function()
    if debugging_memory then
      for k, v in pairs(system.type_count()) do
        print(k, v)
      end
      print("-- " .. math.round(tonumber(collectgarbage("count"))/1024, 3) .. "MB --")
      print()
    end
  end)

  --[[
  print(table.tostring(love.graphics.getSupported()))
  print(love.graphics.getRendererInfo())
  local formats = love.graphics.getImageFormats()
  for f, s in pairs(formats) do print(f, tostring(s)) end
  local canvasformats = love.graphics.getCanvasFormats()
  for f, s in pairs(canvasformats) do print(f, tostring(s)) end
  print(table.tostring(love.graphics.getSystemLimits()))
  print(table.tostring(love.graphics.getStats()))
  ]]--

  -- Last, so that every class, data table and the first state already exist by
  -- the time the accessibility layer wraps them.
  access.init()
end


function update(dt)
  -- Runs before the game so that synthetic clicks from keyboard navigation are
  -- visible to widgets in the same frame they were requested.
  access.update(dt)
  main:update(dt)

  --[[
  if input.b.pressed then
    -- debugging_memory = not debugging_memory
    for k, v in pairs(system.type_count()) do
      print(k, v)
    end
    print("-- " .. math.round(tonumber(collectgarbage("count"))/1024, 3) .. "MB --")
    print()
  end
  ]]--

  --[[
  if input.n.pressed then
    if main.current.sfx_button then
      main.current.sfx_button:action()
      main.current.sfx_button.selected = false
    else
      if sfx.volume == 0.5 then
        sfx.volume = 0
        state.volume_muted = true
      elseif sfx.volume == 0 then
        sfx.volume = 0.5
        state.volume_muted = false
      end
    end
  end

  if input.m.pressed then
    if main.current.music_button then
      main.current.music_button:action()
      main.current.music_button.selected = false
    else
      if music.volume == 0.5 then
        state.music_muted = true
        music.volume = 0
      elseif music.volume == 0 then
        music.volume = 0.5
        state.music_muted = false
      end
    end
  end
  ]]--

  if input.k.pressed then
    if sx > 1 and sy > 1 then
      sx, sy = sx - 0.5, sy - 0.5
      love.window.setMode(480*sx, 270*sy)
      state.sx, state.sy = sx, sy
      state.fullscreen = false
    end
  end

  if input.l.pressed then
    sx, sy = sx + 0.5, sy + 0.5
    love.window.setMode(480*sx, 270*sy)
    state.sx, state.sy = sx, sy
    state.fullscreen = false
  end

  --[[
  if input.f11.pressed then
    steam.userStats.resetAllStats(true)
    steam.userStats.storeStats()
  end
  ]]--
end


function draw()
  shared_draw(function()
    main:draw()
  end)
end


-- Where the buttons of one options row go, worked out from the row's own
-- labels rather than written down. Every label changes length with the
-- language, and a hardcoded x only ever fits the language it was measured in.
-- Returns one {x, w, text} per label, laid out left to right and centred on
-- the screen.
function options_row(...)
  local labels = {...}
  local gap, total, widths = 8, 0, {}
  for i, label in ipairs(labels) do
    widths[i] = pixul_font:get_text_width(label) + 8
    total = total + widths[i]
  end

  -- A row that will not fit closes its gaps up rather than running off both
  -- edges. Every row fits in the two languages shipped; this is here so that a
  -- third one crowds instead of losing its outermost buttons.
  local gaps = #labels - 1
  if gaps > 0 and total + gap*gaps > gw - 8 then
    gap = math.max(2, math.floor((gw - 8 - total)/gaps))
  end
  total = total + gap*gaps

  local out, x = {}, gw/2 - total/2
  for i, label in ipairs(labels) do
    out[i] = {x = x + widths[i]/2, w = widths[i], text = label}
    x = x + widths[i] + gap
  end
  return unpack(out)
end


-- Everything open_options puts on the screen, in one list, so that tearing the
-- panel down and building it again are each one call. Changing the language
-- does both, because the rows are laid out from the width of their labels and
-- new labels need new positions as well as new text.
local option_widgets = {
  'paused_t1', 'paused_t2', 'ng_t', 'resume_button', 'restart_button', 'mouse_button',
  'dark_transition_button', 'run_timer_button', 'sfx_button', 'music_button',
  'video_button_1', 'video_button_2', 'video_button_3', 'video_button_4',
  'screen_shake_button', 'screen_movement_button', 'cooldown_snake_button',
  'arrow_snake_button', 'language_button', 'ng_plus_plus_button', 'ng_plus_minus_button',
  'main_menu_button', 'quit_button',
}


function destroy_option_widgets(self)
  for _, name in ipairs(option_widgets) do
    if self[name] then
      self[name].dead = true
      self[name] = nil
    end
  end
  access.destroy_options(self)
end


function build_options(self)
  if self:is(Arena) then
    self.paused_t1 = Text2{group = self.ui, x = gw/2, y = gh/2 - 108, sx = 0.6, sy = 0.6, lines = {{text = '[bg10]' .. T('ui.pause.turn_keys'), font = fat_font, alignment = 'center'}}}
    self.paused_t2 = Text2{group = self.ui, x = gw/2, y = gh/2 - 92, lines = {{text = '[bg10]' .. T('ui.pause.turn_labels'), font = pixul_font, alignment = 'center'}}}
  end

  self.resume_button = Button{group = self.ui, x = gw/2, y = gh - 225, force_update = true,
    button_text = self:is(MainMenu) and T('ui.options.main_menu_esc') or T('ui.options.resume_esc'),
    fg_color = 'bg10', bg_color = 'bg', action = function(b) close_options(self) end}

  -- A tutorial run has no run behind it: the same key and the same place on
  -- the screen start the lesson over instead.
  if self.lesson then
    self.restart_button = Button{group = self.ui, x = gw/2, y = gh - 200, force_update = true, button_text = T('ui.options.restart_lesson'),
      fg_color = 'bg10', bg_color = 'bg', action = function(b) self:restart_lesson() end}

  elseif not self:is(MainMenu) then
    self.restart_button = Button{group = self.ui, x = gw/2, y = gh - 200, force_update = true, button_text = T('ui.options.restart_run'), fg_color = 'bg10', bg_color = 'bg', action = function(b)
      self.transitioning = true
      ui_transition2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      TransitionEffect{group = main.transitions, x = gw/2, y = gh/2, color = state.dark_transitions and bg[-2] or fg[0], transition_action = function()
        slow_amount = 1
        music_slow_amount = 1
        run_time = 0
        gold = 3
        passives = {}
        main_song_instance:stop()
        run_passive_pool = {
          'centipede', 'ouroboros_technique_r', 'ouroboros_technique_l', 'amplify', 'resonance', 'ballista', 'call_of_the_void', 'crucio', 'speed_3', 'damage_4', 'shoot_5', 'death_6', 'lasting_7',
          'defensive_stance', 'offensive_stance', 'kinetic_bomb', 'porcupine_technique', 'last_stand', 'seeping', 'deceleration', 'annihilation', 'malediction', 'hextouch', 'whispers_of_doom',
          'tremor', 'heavy_impact', 'fracture', 'meat_shield', 'hive', 'baneling_burst', 'blunt_arrow', 'explosive_arrow', 'divine_machine_arrow', 'chronomancy', 'awakening', 'divine_punishment',
          'assassination', 'flying_daggers', 'ultimatum', 'magnify', 'echo_barrage', 'unleash', 'reinforce', 'payback', 'enchanted', 'freezing_field', 'burning_field', 'gravity_field', 'magnetism',
          'insurance', 'dividends', 'berserking', 'unwavering_stance', 'unrelenting_stance', 'blessing', 'haste', 'divine_barrage', 'orbitism', 'psyker_orbs', 'psychosink', 'rearm', 'taunt', 'construct_instability',
          'intimidation', 'vulnerability', 'temporal_chains', 'ceremonial_dagger', 'homing_barrage', 'critical_strike', 'noxious_strike', 'infesting_strike', 'burning_strike', 'lucky_strike', 'healing_strike', 'stunning_strike',
          'silencing_strike', 'culling_strike', 'lightning_strike', 'psycholeak', 'divine_blessing', 'hardening', 'kinetic_strike',
        }
        max_units = math.clamp(7 + current_new_game_plus, 7, 12)
        main:add(BuyScreen'buy_screen')
        locked_state = nil
        system.save_run()
        main:go_to('buy_screen', 1, 0, {}, passives, 1, 0)
      end, text = Text({{text = '[wavy, ' .. tostring(state.dark_transitions and 'fg' or 'bg') .. ']' .. T('ui.transition.restarting'), font = pixul_font, alignment = 'center'}}, global_text_tags)}
    end}
  end

  -- Rows are measured before anything is built, so each one can be centred as a
  -- whole. Toggle labels are measured in their current state, which is what the
  -- old hardcoded widths were approximating.
  local function yn(v) return v and T('ui.yes') or T('ui.no') end

  local sfx_spec, music_spec = options_row(
    T('ui.options.sfx_volume', (state.sfx_volume or 0.5)*10),
    T('ui.options.music_volume', (state.music_volume or 0.5)*10))
  local mouse_spec, dark_spec, timer_spec, language_spec = options_row(
    T('ui.options.mouse_control', yn(state.mouse_control)),
    T('ui.options.dark_transitions', yn(state.dark_transitions)),
    T('ui.options.run_timer', yn(state.run_timer)),
    T('ui.options.language', loc.language_name()))
  local size_down_spec, size_up_spec, fullscreen_spec, reset_video_spec = options_row(
    T('ui.options.window_size_down'), T('ui.options.window_size_up'),
    T('ui.options.fullscreen'), T('ui.options.reset_video'))
  local shake_spec, cooldown_spec = options_row(
    T('ui.options.screen_shake', yn(not state.no_screen_shake)),
    T('ui.options.cooldown_snake', yn(state.cooldown_snake)))
  local movement_spec, arrow_spec = options_row(
    T('ui.options.screen_movement', yn(not state.no_screen_movement)),
    T('ui.options.arrow_snake', yn(state.arrow_snake)))

  self.sfx_button = Button{group = self.ui, x = sfx_spec.x, y = gh - 175, w = sfx_spec.w, force_update = true, button_text = sfx_spec.text, fg_color = 'bg10', bg_color = 'bg',
  action = function(b)
    ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    b.spring:pull(0.2, 200, 10)
    b.selected = true
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    sfx.volume = sfx.volume + 0.1
    if sfx.volume > 1 then sfx.volume = 0 end
    state.sfx_volume = sfx.volume
    b:set_text(T('ui.options.sfx_volume', (state.sfx_volume or 0.5)*10))
  end,
  action_2 = function(b)
    ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    b.spring:pull(0.2, 200, 10)
    b.selected = true
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    sfx.volume = sfx.volume - 0.1
    if math.abs(sfx.volume) < 0.001 and sfx.volume > 0 then sfx.volume = 0 end
    if sfx.volume < 0 then sfx.volume = 1 end
    state.sfx_volume = sfx.volume
    b:set_text(T('ui.options.sfx_volume', (state.sfx_volume or 0.5)*10))
  end}

  self.music_button = Button{group = self.ui, x = music_spec.x, y = gh - 175, w = music_spec.w, force_update = true, button_text = music_spec.text, fg_color = 'bg10', bg_color = 'bg',
  action = function(b)
    ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    b.spring:pull(0.2, 200, 10)
    b.selected = true
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    music.volume = music.volume + 0.1
    if music.volume > 1 then music.volume = 0 end
    state.music_volume = music.volume
    b:set_text(T('ui.options.music_volume', (state.music_volume or 0.5)*10))
  end,
  action_2 = function(b)
    ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    b.spring:pull(0.2, 200, 10)
    b.selected = true
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    music.volume = music.volume - 0.1
    if math.abs(music.volume) < 0.001 and music.volume > 0 then music.volume = 0 end
    if music.volume < 0 then music.volume = 1 end
    state.music_volume = music.volume
    b:set_text(T('ui.options.music_volume', (state.music_volume or 0.5)*10))
  end}

  self.mouse_button = Button{group = self.ui, x = mouse_spec.x, y = gh - 150, w = mouse_spec.w, force_update = true, button_text = mouse_spec.text, fg_color = 'bg10', bg_color = 'bg',
  action = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    state.mouse_control = not state.mouse_control
    b:set_text(T('ui.options.mouse_control', yn(state.mouse_control)))
  end}

  self.dark_transition_button = Button{group = self.ui, x = dark_spec.x, y = gh - 150, w = dark_spec.w, force_update = true, button_text = dark_spec.text,
  fg_color = 'bg10', bg_color = 'bg', action = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    state.dark_transitions = not state.dark_transitions
    b:set_text(T('ui.options.dark_transitions', yn(state.dark_transitions)))
  end}

  self.run_timer_button = Button{group = self.ui, x = timer_spec.x, y = gh - 150, w = timer_spec.w, force_update = true, button_text = timer_spec.text, fg_color = 'bg10', bg_color = 'bg',
  action = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    state.run_timer = not state.run_timer
    b:set_text(T('ui.options.run_timer', yn(state.run_timer)))
  end}

  self.video_button_1 = Button{group = self.ui, x = size_down_spec.x, y = gh - 125, w = size_down_spec.w, force_update = true, button_text = size_down_spec.text, fg_color = 'bg10', bg_color = 'bg', action = function()
    if sx > 1 and sy > 1 then
      ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      sx, sy = sx - 0.5, sy - 0.5
      love.window.setMode(480*sx, 270*sy)
      state.sx, state.sy = sx, sy
      state.fullscreen = false
    end
  end}

  self.video_button_2 = Button{group = self.ui, x = size_up_spec.x, y = gh - 125, w = size_up_spec.w, force_update = true, button_text = size_up_spec.text, fg_color = 'bg10', bg_color = 'bg', action = function()
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    sx, sy = sx + 0.5, sy + 0.5
    love.window.setMode(480*sx, 270*sy)
    state.sx, state.sy = sx, sy
    state.fullscreen = false
  end}

  self.video_button_3 = Button{group = self.ui, x = fullscreen_spec.x, y = gh - 125, w = fullscreen_spec.w, force_update = true, button_text = fullscreen_spec.text, fg_color = 'bg10', bg_color = 'bg', action = function()
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    local _, _, flags = love.window.getMode()
    local window_width, window_height = love.window.getDesktopDimensions(flags.display)
    sx, sy = window_width/480, window_height/270
    state.sx, state.sy = sx, sy
    ww, wh = window_width, window_height
    love.window.setMode(window_width, window_height)
  end}

  self.video_button_4 = Button{group = self.ui, x = reset_video_spec.x, y = gh - 125, w = reset_video_spec.w, force_update = true, button_text = reset_video_spec.text, fg_color = 'bg10', bg_color = 'bg', action = function()
    local _, _, flags = love.window.getMode()
    local window_width, window_height = love.window.getDesktopDimensions(flags.display)
    sx, sy = window_width/480, window_height/270
    ww, wh = window_width, window_height
    state.sx, state.sy = sx, sy
    state.fullscreen = false
    ww, wh = window_width, window_height
    love.window.setMode(window_width, window_height)
  end}

  self.screen_shake_button = Button{group = self.ui, x = shake_spec.x, y = gh - 100, w = shake_spec.w, force_update = true, button_text = shake_spec.text,
  fg_color = 'bg10', bg_color = 'bg', action = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    state.no_screen_shake = not state.no_screen_shake
    b:set_text(T('ui.options.screen_shake', yn(not state.no_screen_shake)))
  end}

  self.cooldown_snake_button = Button{group = self.ui, x = cooldown_spec.x, y = gh - 100, w = cooldown_spec.w, force_update = true, button_text = cooldown_spec.text,
  fg_color = 'bg10', bg_color = 'bg', action = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    state.cooldown_snake = not state.cooldown_snake
    b:set_text(T('ui.options.cooldown_snake', yn(state.cooldown_snake)))
  end}

  self.screen_movement_button = Button{group = self.ui, x = movement_spec.x, y = gh - 75, w = movement_spec.w, force_update = true, button_text = movement_spec.text,
  fg_color = 'bg10', bg_color = 'bg', action = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    state.no_screen_movement = not state.no_screen_movement
    if state.no_screen_movement then
      camera.x, camera.y = gw/2, gh/2
      camera.r = 0
    end
    b:set_text(T('ui.options.screen_movement', yn(not state.no_screen_movement)))
  end}

  self.arrow_snake_button = Button{group = self.ui, x = arrow_spec.x, y = gh - 75, w = arrow_spec.w, force_update = true, button_text = arrow_spec.text,
  fg_color = 'bg10', bg_color = 'bg', action = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    state.arrow_snake = not state.arrow_snake
    b:set_text(T('ui.options.arrow_snake', yn(state.arrow_snake)))
  end}

  -- Left click walks forwards through the languages and right click backwards,
  -- which is how the volume buttons a row up already behave.
  self.language_button = Button{group = self.ui, x = language_spec.x, y = gh - 150, w = language_spec.w, force_update = true, button_text = language_spec.text,
  fg_color = 'bg10', bg_color = 'bg', action = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    if loc.next() then change_language(self) end
  end,
  action_2 = function(b)
    ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
    if loc.previous() then change_language(self) end
  end}

  if self:is(MainMenu) then
    -- The counter shares the row with the two buttons that move it, so it is
    -- laid out as a third cell and then dropped into place.
    local ng_down_spec, ng_up_spec, ng_label_spec = options_row(
      T('ui.options.ng_down'), T('ui.options.ng_up'), T('ui.options.ng_current', current_new_game_plus))
    self.ng_t = Text2{group = self.ui, x = ng_label_spec.x, y = gh - 50, lines = {{text = '[bg10]' .. ng_label_spec.text, font = pixul_font, alignment = 'center'}}}

    local function set_ng(delta, ceiling)
      current_new_game_plus = math.clamp(current_new_game_plus + delta, 0, ceiling)
      state.current_new_game_plus = current_new_game_plus
      self.ng_t.text:set_text({{text = '[bg10]' .. T('ui.options.ng_current', current_new_game_plus), font = pixul_font, alignment = 'center'}})
      max_units = 7 + current_new_game_plus
      system.save_run()
    end

    self.ng_plus_minus_button = Button{group = self.ui, x = ng_down_spec.x, y = gh - 50, w = ng_down_spec.w, force_update = true, button_text = ng_down_spec.text, fg_color = 'bg10', bg_color = 'bg', action = function(b)
      ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      b.spring:pull(0.2, 200, 10)
      b.selected = true
      set_ng(-1, 5)
    end}

    self.ng_plus_plus_button = Button{group = self.ui, x = ng_up_spec.x, y = gh - 50, w = ng_up_spec.w, force_update = true, button_text = ng_up_spec.text, fg_color = 'bg10', bg_color = 'bg', action = function(b)
      ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      b.spring:pull(0.2, 200, 10)
      b.selected = true
      set_ng(1, new_game_plus)
    end}

  else
    self.main_menu_button = Button{group = self.ui, x = gw/2, y = gh - 50, force_update = true, button_text = T('ui.options.main_menu'), fg_color = 'bg10', bg_color = 'bg', action = function(b)
      self.transitioning = true
      ui_transition2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      ui_switch2:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      ui_switch1:play{pitch = random:float(0.95, 1.05), volume = 0.5}
      TransitionEffect{group = main.transitions, x = gw/2, y = gh/2, color = state.dark_transitions and bg[-2] or fg[0], transition_action = function()
        slow_amount = 1
        music_slow_amount = 1
        main:add(MainMenu'main_menu')
        -- Leaving a lesson goes back to the list it was picked from, not to
        -- the bare menu: nobody opens one lesson and then stops.
        main:go_to('main_menu', self.lesson and (self.lesson.key or true) or nil)
      end, text = Text({{text = '[wavy, ' .. tostring(state.dark_transitions and 'fg' or 'bg') .. ']' .. T('ui.transition.dots'), font = pixul_font, alignment = 'center'}}, global_text_tags)}
    end}
  end

  self.quit_button = Button{group = self.ui, x = gw/2, y = gh - 25, force_update = true, button_text = T('ui.options.quit'), fg_color = 'bg10', bg_color = 'bg', action = function()
    system.save_state()
    steam.shutdown()
    love.event.quit()
  end}

  access.create_options(self)
end


-- The panel is rebuilt in place so the new language is visible immediately.
-- The screen behind it is not, because tearing down a shop or an arena to
-- relabel it is not worth the risk; the main menu is cheap and safe to rebuild,
-- so it is done when the panel closes.
function change_language(self)
  system.save_state()
  destroy_option_widgets(self)
  build_options(self)
  if self:is(MainMenu) then self.language_changed = true end
  access.say(T('a11y.language_set', loc.language_name()), {interrupt = true, priority = true})
end


function open_options(self)
  input:set_mouse_visible(true)
  trigger:tween(0.25, _G, {slow_amount = 0}, math.linear, function()
    slow_amount = 0
    self.paused = true
    build_options(self)
  end, 'pause')
end


function close_options(self)
  trigger:tween(0.25, _G, {slow_amount = 1}, math.linear, function()
    slow_amount = 1
    self.paused = false
    destroy_option_widgets(self)
    system.save_state()
    if self:is(MainMenu) or self:is(BuyScreen) then input:set_mouse_visible(true)
    elseif self:is(Arena) then input:set_mouse_visible(state.mouse_control or false) end

    -- A language change leaves the menu underneath in the old language. It is
    -- rebuilt from scratch rather than relabelled, the same way the "main menu"
    -- button elsewhere gets back to a clean menu.
    if self.language_changed then
      self.language_changed = nil
      trigger:after(0.01, function()
        main:add(MainMenu'main_menu')
        main:go_to('main_menu')
      end)
    end
  end, 'pause')
end


function love.run()
  return engine_run({
    game_name = 'SNKRX',
    window_width = 'max',
    window_height = 'max',
  })
end
