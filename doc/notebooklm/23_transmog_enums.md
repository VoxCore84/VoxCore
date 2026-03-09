# Transmog Enumerations — Quick Reference

> Source: `ExtTools/Transmog_DeepDive/source_lua/*Documentation.lua` (build 66263)
> Full wiki: `doc/transmog_deepdive_wiki.md`

## TransmogOutfitDisplayType (CRITICAL — 5 values)

```
Unassigned = 0    Empty row, no appearance
Assigned   = 1    Normal appearance applied
Equipped   = 2    Show equipped item (passthrough)
Hidden     = 3    Hidden appearance (slot invisible)
Disabled   = 4    Paired placeholder / disabled
```

**WARNING**: Previous docs had Hidden=2, Equipped=3. WRONG. Hidden=3, Equipped=2.
**WARNING**: Do NOT confuse with DB2 ItemAppearance.DisplayType (range 0-15, routing DT). See wiki §19.

## TransmogOutfitSlot (15 values — used by outfit system)

```
Head=0  ShoulderRight=1  ShoulderLeft=2  Back=3  Chest=4
Tabard=5  Body=6  Wrist=7  Hand=8  Waist=9  Legs=10  Feet=11
WeaponMainHand=12  WeaponOffHand=13  WeaponRanged=14
```

## TransmogSlot (13 values — legacy collection UI)

```
Head=0 Shoulder=1 Back=2 Chest=3 Body=4 Tabard=5
Wrist=6 Hand=7 Waist=8 Legs=9 Feet=10 Mainhand=11 Offhand=12
```

## TransmogOutfitSlotOption (12 values — weapon options)

```
None=0  OneHandedWeapon=1  TwoHandedWeapon=2  RangedWeapon=3
OffHand=4  Shield=5  DeprecatedReuseMe=6(Dagger)  FuryTwoHandedWeapon=7
ArtifactSpecOne=8  ArtifactSpecTwo=9  ArtifactSpecThree=10  ArtifactSpecFour=11
```

## TransmogCollectionType (30 values)

```
None=0  Head=1  Shoulder=2  Back=3  Chest=4  Shirt=5  Tabard=6
Wrist=7  Hands=8  Waist=9  Legs=10  Feet=11  Wand=12
OneHAxe=13  OneHSword=14  OneHMace=15  Dagger=16  Fist=17
Shield=18  Holdable=19  TwoHAxe=20  TwoHSword=21  TwoHMace=22
Staff=23  Polearm=24  Bow=25  Gun=26  Crossbow=27  Warglaives=28  Paired=29
```

## TransmogType

```
Appearance=0  Illusion=1
```

## TransmogModification

```
Main=0  Secondary=1
```

## TransmogOutfitSlotFlags (bitmask)

```
CannotBeHidden=1  CanHaveIllusions=2  IsSecondarySlot=4
```

## TransmogOutfitSlotOptionFlags (bitmask)

```
IllusionNotAllowed=1  DynamicOptionName=2  DisablesOffhandSlot=4
```

## TransmogSituation (22 values — NEW in 12.x)

```
AllSpecs=0 Spec=1 AllLocations=2 LocationRested=3 LocationHouse=4
LocationCharacterSelect=5 LocationWorld=6 LocationDelves=7 LocationDungeons=8
LocationRaids=9 LocationArenas=10 LocationBattlegrounds=11
AllMovement=12 MovementUnmounted=13 MovementSwimming=14
MovementGroundMount=15 MovementFlyingMount=16
AllEquipmentSets=17 EquipmentSets=18
AllRacialForms=19 FormNative=20 FormNonNative=21
```

## TransmogOutfitEquipAction

```
Equip=0 EquipAndLock=1 Remove=2 RemoveAndLock=3 Unlock=4 Lock=5
```

## TransmogOutfitSlotError (15 values)

```
Ok=0 NoItem=1 NotSoulbound=2 Legendary=3 InvalidItemType=4
InvalidDestination=5 Mismatch=6 SameItem=7 InvalidSource=8
InvalidSourceQuality=9 CannotUseItem=10 InvalidSlotForRace=11
NoIllusion=12 InvalidSlotForForm=13 IncompatibleWithMainHand=14
```

## TransmogOutfitSlotWarning (6 values)

```
Ok=0 InvalidEquippedDestinationItem=1 WrongWeaponCategoryEquipped=2
PendingWeaponChanges=3 WeaponDoesNotSupportIllusions=4 NothingEquipped=5
```

## TransmogSource (11 values)

```
None=0 JournalEncounter=1 Quest=2 Vendor=3 WorldDrop=4
HiddenUntilCollected=5 CantCollect=6 Achievement=7 Profession=8
NotValidForTransmog=9 TradingPost=10
```

## TransmogOutfitTransactionFlags (bitmask)

```
UpdateMetadata=1 UpdateOutfitInfo=2 CreateOutfitInfo=4
UpdateSlots=8 UpdateSituations=16
AddNewOutfitMask=20 FullOutfitUpdateMask=27 AddOutfitAndUpdateSlots=28
```

## Constants

```
NoTransmogID = 0
MainHandTransmogIsIndividualWeapon = -1
MainHandTransmogIsPairedWeapon = 0
EQUIP_TRANSMOG_OUTFIT_MANUAL_SPELL_ID = 1247613
TRANSMOG_OUTFIT_SLOT_NONE = -1
```
