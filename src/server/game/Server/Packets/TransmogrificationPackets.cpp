/*
 * This file is part of the TrinityCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "TransmogrificationPackets.h"
#include "Log.h"
#include "PacketOperators.h"
#include "Util.h"
#include <algorithm>
#include <cctype>
#include <span>
#include <sstream>

namespace WorldPackets::Transmogrification
{

namespace
{
void CapturePayloadDebugInfo(WorldPacket const& packet, size_t& payloadSize, std::string& payloadPreviewHex)
{
    // Capture readable payload starting from current rpos (past the opcode bytes)
    size_t readable = packet.size() - packet.rpos();
    payloadSize = readable;
    size_t previewSize = std::min<size_t>(readable, 128);
    payloadPreviewHex = ByteArrayToHexStr(std::span(packet.data() + packet.rpos(), previewSize));
}

template <typename T>
T ReadLE(std::span<uint8 const> payload, size_t offset)
{
    T value = 0;
    for (size_t i = 0; i < sizeof(T) && (offset + i) < payload.size(); ++i)
        value |= T(payload[offset + i]) << (i * 8);
    return value;
}

std::string BuildDiagnosticReadTrace(char const* opcodeName, WorldPacket const& packet)
{
    std::span<uint8 const> payload(packet.data(), packet.size());
    std::ostringstream trace;
    trace << opcodeName << " payload-bytes=" << payload.size();

    if (payload.size() >= 1)
        trace << " | u8@0=" << uint32(payload[0]);
    if (payload.size() >= 2)
        trace << " | u16@0=" << ReadLE<uint16>(payload, 0);
    if (payload.size() >= 4)
        trace << " | u32@0=" << ReadLE<uint32>(payload, 0);
    if (payload.size() >= 8)
        trace << " | u64@0=" << ReadLE<uint64>(payload, 0);
    if (payload.size() >= 12)
        trace << " | u32@4=" << ReadLE<uint32>(payload, 4);
    if (payload.size() >= 16)
        trace << " | u64@8=" << ReadLE<uint64>(payload, 8);

    return trace.str();
}

uint8 TransmogOutfitSlotToEquipSlot(uint8 transmogSlot)
{
    // 12.x client uses 1-based transmog slot indices (15 slots, no gaps):
    //   1=Head, 2=Shoulder, 3=SecShoulder, 4=Back, 5=Chest, 6=Body(shirt),
    //   7=Tabard, 8=Wrists, 9=Hands, 10=Waist, 11=Legs, 12=Feet,
    //   13=MainHand, 14=OffHand, 15=Ranged
    switch (transmogSlot)
    {
        case 1:  return EQUIPMENT_SLOT_HEAD;
        case 2:  return EQUIPMENT_SLOT_SHOULDERS;
        case 3:  return TRANSMOG_SECONDARY_SHOULDER_SLOT;
        case 4:  return EQUIPMENT_SLOT_BACK;
        case 5:  return EQUIPMENT_SLOT_CHEST;
        case 6:  return EQUIPMENT_SLOT_BODY;
        case 7:  return EQUIPMENT_SLOT_TABARD;
        case 8:  return EQUIPMENT_SLOT_WRISTS;
        case 9:  return EQUIPMENT_SLOT_HANDS;
        case 10: return EQUIPMENT_SLOT_WAIST;
        case 11: return EQUIPMENT_SLOT_LEGS;
        case 12: return EQUIPMENT_SLOT_FEET;
        case 13: return EQUIPMENT_SLOT_MAINHAND;
        case 14: return EQUIPMENT_SLOT_OFFHAND;
        case 15: return EQUIPMENT_SLOT_RANGED;
        default: return EQUIPMENT_SLOT_END;
    }
}
}

ByteBuffer& operator>>(ByteBuffer& data, TransmogrifyItem& transmogItem)
{
    data >> transmogItem.ItemModifiedAppearanceID;
    data >> transmogItem.Slot;
    data >> transmogItem.SpellItemEnchantmentID;
    data >> transmogItem.SecondaryItemModifiedAppearanceID;

    return data;
}

void TransmogrifyItems::Read()
{
    _worldPacket >> Size<uint32>(Items);
    _worldPacket >> Npc;
    for (TransmogrifyItem& item : Items)
        _worldPacket >> item;

    _worldPacket >> Bits<1>(CurrentSpecOnly);
}

void TransmogOutfitNew::Read()
{
    CapturePayloadDebugInfo(_worldPacket, PayloadSize, PayloadPreviewHex);

    Set.Type = EquipmentSetInfo::TRANSMOG;
    ParseSuccess = false;

    try
    {
        _worldPacket >> Npc;

        std::size_t rposAfterGuid = _worldPacket.rpos();
        std::span<uint8 const> remaining(_worldPacket.data() + rposAfterGuid, _worldPacket.size() - rposAfterGuid);
        if (remaining.size() < 8)
        {
            ParseError = Trinity::StringFormat("payload too short for CMSG_TRANSMOG_OUTFIT_NEW (remaining={})", remaining.size());
            DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_NEW", _worldPacket);
            return;
        }

        // NEW middle format: [type:u8][flags:u8][icon:u32][...slot data (16 bytes each)...][nameLen:u8][pad:u8][name bytes]
        MiddleType = remaining[0];
        MiddleFlags = remaining[1];
        IconFileDataID = ReadLE<uint32>(remaining, 2);

        // Fixed header is 6 bytes: type(1) + flags(1) + icon(4)
        // After the fixed header and any slot data, we have: [nameLen:u8][pad:u8][name:nameLen bytes]
        // Work backward from the end using the length byte to find the name
        // The nameLen byte is at (remaining.size() - nameLen - 2), pad is at (remaining.size() - nameLen - 1)

        // First, use the length-byte approach: scan for the nameLen/pad pair
        // The name ends at the very end of the payload. The byte at offset (end - nameLen - 2) should equal nameLen.
        // We try the length-byte method first, then fall back to ASCII scan for diagnostics.

        std::size_t nameLength = 0;
        std::size_t nameStart = 0;
        bool usedLengthByte = false;

        // Try length-byte parsing: iterate possible name lengths (1..127)
        // The nameLen byte is at (remaining.size() - candidateLen - 2), pad byte at (remaining.size() - candidateLen - 1)
        for (std::size_t candidateLen = 1; candidateLen <= 127 && candidateLen + 2 <= remaining.size(); ++candidateLen)
        {
            std::size_t lenByteOffset = remaining.size() - candidateLen - 2;
            if (lenByteOffset < 6) // must be after the 6-byte fixed header
                break;
            if (remaining[lenByteOffset] == candidateLen && remaining[lenByteOffset + 1] == 0x00)
            {
                // Validate that the space between fixed header and lenByte is a multiple of 16 (slot data)
                std::size_t slotRegion = lenByteOffset - 6;
                if (slotRegion % 16 == 0)
                {
                    nameLength = candidateLen;
                    nameStart = lenByteOffset + 2;
                    usedLengthByte = true;
                    break;
                }
            }
        }

        if (!usedLengthByte)
        {
            // Fallback: backward ASCII scan (original method)
            std::size_t asciiStart = remaining.size();
            while (asciiStart > 0)
            {
                uint8 b = remaining[asciiStart - 1];
                if (b < 0x20 || b > 0x7E)
                    break;
                --asciiStart;
            }

            nameLength = remaining.size() - asciiStart;
            if (nameLength == 0 || asciiStart < 2)
            {
                ParseError = "missing trailing outfit name or name trailer";
                DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_NEW", _worldPacket);
                return;
            }

            uint8 nameLengthByte = remaining[asciiStart - 2];
            if (nameLengthByte != nameLength)
            {
                ParseError = Trinity::StringFormat("name length mismatch (lenByte={} trailingAsciiLen={})", nameLengthByte, nameLength);
                DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_NEW", _worldPacket);
                return;
            }

            nameStart = asciiStart;
            TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_NEW: used ASCII fallback for name parsing (non-ASCII name or wire format changed?)");
        }

        std::size_t slotDataEnd = nameStart - 2; // offset of nameLen byte
        std::size_t extraBytes = slotDataEnd - 6;
        if (extraBytes > 0 && extraBytes % 16 != 0)
            TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_NEW: {} extra middle bytes (not multiple of 16), ignoring", extraBytes);
        else if (extraBytes > 0)
        {
            std::span<uint8 const> slotData = remaining.subspan(6, extraBytes);
            for (std::size_t i = 0; i < slotData.size(); i += 16)
            {
                uint32 appearanceID = ReadLE<uint32>(slotData, i + 0);
                uint32 rawSlotField = ReadLE<uint32>(slotData, i + 4);
                uint8 transmogSlot = uint8(rawSlotField >> 24);
                uint8 equipSlot = TransmogOutfitSlotToEquipSlot(transmogSlot);

                if (equipSlot == TRANSMOG_SECONDARY_SHOULDER_SLOT)
                {
                    Set.SecondaryShoulderApparanceID = int32(appearanceID);
                    Set.SecondaryShoulderSlot = 2;
                }
                else if (equipSlot < EQUIPMENT_SLOT_END)
                    Set.Appearances[equipSlot] = int32(appearanceID);
            }
        }

        Set.IgnoreMask = 0;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            if (!Set.Appearances[slot])
                Set.IgnoreMask |= (1u << slot);

        Set.SetName.assign(reinterpret_cast<char const*>(remaining.data() + nameStart), nameLength);
        Set.SetIcon = std::to_string(IconFileDataID);
        ParseSuccess = true;
        ParseError.clear();

        DiagnosticReadTrace = Trinity::StringFormat("npc={} rposAfterGuid={} middleType={} middleFlags={} iconFileDataId={} name='{}' usedLengthByte={}",
            Npc.ToString(), rposAfterGuid, MiddleType, MiddleFlags, IconFileDataID, Set.SetName, usedLengthByte);

        TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_NEW diag: {}", DiagnosticReadTrace);
    }
    catch (std::exception const& ex)
    {
        ParseSuccess = false;
        ParseError = ex.what();
        DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_NEW", _worldPacket);
    }

    _worldPacket.rfinish();
}

void TransmogOutfitUpdateInfo::Read()
{
    CapturePayloadDebugInfo(_worldPacket, PayloadSize, PayloadPreviewHex);

    ParseSuccess = false;
    Set.Type = EquipmentSetInfo::TRANSMOG;

    try
    {
        _worldPacket >> Set.SetID;
        _worldPacket >> Npc;

        std::size_t rposAfterGuid = _worldPacket.rpos();
        std::span<uint8 const> remaining(_worldPacket.data() + rposAfterGuid, _worldPacket.size() - rposAfterGuid);
        if (remaining.size() < 7)
        {
            ParseError = Trinity::StringFormat("payload too short for CMSG_TRANSMOG_OUTFIT_UPDATE_INFO (remaining={})", remaining.size());
            DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_INFO", _worldPacket);
            return;
        }

        // UPDATE_INFO format: [type:u8][icon:u32][nameLen:u8][pad:u8][name:nameLen bytes]
        // Fixed header = 5 bytes (type + icon)
        MiddleType = remaining[0];
        MiddleFlags = 0;
        IconFileDataID = ReadLE<uint32>(remaining, 1);

        std::size_t nameLength = 0;
        std::size_t nameStart = 0;
        bool usedLengthByte = false;

        // Length-byte parsing: nameLen at offset 5, pad at offset 6, name starts at offset 7
        if (remaining.size() >= 7)
        {
            uint8 candidateLen = remaining[5];
            if (candidateLen > 0 && remaining[6] == 0x00 && 7 + candidateLen == remaining.size())
            {
                nameLength = candidateLen;
                nameStart = 7;
                usedLengthByte = true;
            }
        }

        if (!usedLengthByte)
        {
            // Fallback: backward ASCII scan
            std::size_t asciiStart = remaining.size();
            while (asciiStart > 0)
            {
                uint8 b = remaining[asciiStart - 1];
                if (b < 0x20 || b > 0x7E)
                    break;
                --asciiStart;
            }

            nameLength = remaining.size() - asciiStart;
            if (nameLength == 0 || asciiStart < 2)
            {
                ParseError = "missing trailing outfit name or name trailer";
                DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_INFO", _worldPacket);
                return;
            }

            uint8 nameLengthByte = remaining[asciiStart - 2];
            if (nameLengthByte != nameLength)
            {
                ParseError = Trinity::StringFormat("name length mismatch (lenByte={} trailingAsciiLen={})", nameLengthByte, nameLength);
                DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_INFO", _worldPacket);
                return;
            }

            std::size_t middleLength = asciiStart - 2;
            if (middleLength != 5)
            {
                ParseError = Trinity::StringFormat("unexpected middle size for UPDATE_INFO (got={} expected=5)", middleLength);
                DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_INFO", _worldPacket);
                return;
            }

            nameStart = asciiStart;
            TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_UPDATE_INFO: used ASCII fallback for name parsing");
        }

        Set.SetName.assign(reinterpret_cast<char const*>(remaining.data() + nameStart), nameLength);
        Set.SetIcon = std::to_string(IconFileDataID);
        ParseSuccess = true;
        ParseError.clear();

        DiagnosticReadTrace = Trinity::StringFormat("setId={} npc={} rposAfterGuid={} middleType={} iconFileDataId={} name='{}' usedLengthByte={}",
            Set.SetID, Npc.ToString(), rposAfterGuid, MiddleType, IconFileDataID, Set.SetName, usedLengthByte);

        TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_UPDATE_INFO diag: {}", DiagnosticReadTrace);
    }
    catch (std::exception const& ex)
    {
        ParseSuccess = false;
        ParseError = ex.what();
        DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_INFO", _worldPacket);
    }

    _worldPacket.rfinish();
}

void TransmogOutfitUpdateSlots::Read()
{
    CapturePayloadDebugInfo(_worldPacket, PayloadSize, PayloadPreviewHex);

    ParseSuccess = false;

    try
    {
        _worldPacket >> Set.SetID;

        uint32 slotCount = 0;
        _worldPacket >> slotCount;
        _worldPacket >> Npc;

        std::size_t rposAfterGuid = _worldPacket.rpos();

        std::size_t expectedSlotBytes = std::size_t(slotCount) * 16;
        std::size_t bytesRemainingAfterGuid = _worldPacket.size() - _worldPacket.rpos();
        if (bytesRemainingAfterGuid < expectedSlotBytes)
        {
            ParseError = Trinity::StringFormat("slot payload truncated (slotCount={} expectedSlotBytes={} remaining={})", slotCount, expectedSlotBytes, bytesRemainingAfterGuid);
            DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS", _worldPacket);
            _worldPacket.rfinish();
            return;
        }

        // UPDATE_SLOTS has optional trailing alignment bytes between packed guid and slot entries.
        std::size_t bytesBeforeSlots = bytesRemainingAfterGuid - expectedSlotBytes;
        for (std::size_t i = 0; i < bytesBeforeSlots; ++i)
            _worldPacket.read_skip<uint8>();

        Slots.resize(slotCount);

        Set.Type = EquipmentSetInfo::TRANSMOG;
        Set.IgnoreMask = 0;

        TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS diag: setId={} slotCount={} npc={} rposAfterGuid={} bytesBeforeSlots={}",
            Set.SetID, slotCount, Npc.ToString(), rposAfterGuid, bytesBeforeSlots);

        // Log hex dump of first 48 bytes at slot read position for diagnostics
        {
            std::size_t curRpos = _worldPacket.rpos();
            std::size_t dumpSize = std::min<std::size_t>(48, _worldPacket.size() - curRpos);
            TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS slot data at rpos={}: {}",
                curRpos, ByteArrayToHexStr(std::span(_worldPacket.data() + curRpos, dumpSize)));
        }

        for (uint32 i = 0; i < slotCount; ++i)
        {
            TransmogOutfitSlotEntry& slot = Slots[i];

            // Read 16 raw bytes per entry
            _worldPacket.read(slot.RawBytes, 16);

            // Wire format: [u8:0x00][u32:AppearanceID LE][u8:Flags][9 bytes:reserved][u8:SlotIndex]
            slot.AppearanceID = ReadLE<uint32>(std::span<uint8 const>(slot.RawBytes, 16), 1);
            slot.Flags = slot.RawBytes[5];
            slot.SlotIndex = slot.RawBytes[15];

            uint8 transmogSlot = slot.SlotIndex;
            uint8 equipSlot = TransmogOutfitSlotToEquipSlot(transmogSlot);
            if (equipSlot == TRANSMOG_SECONDARY_SHOULDER_SLOT)
            {
                Set.SecondaryShoulderApparanceID = int32(slot.AppearanceID);
                Set.SecondaryShoulderSlot = 2;
            }
            else if (equipSlot < EQUIPMENT_SLOT_END)
                Set.Appearances[equipSlot] = int32(slot.AppearanceID);

            if (i < 3)
                TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS entry[{}]: raw={} appear={} flags={} transmogSlot={} equipSlot={}",
                    i, ByteArrayToHexStr(std::span<uint8 const>(slot.RawBytes, 16)), slot.AppearanceID, slot.Flags, transmogSlot, equipSlot);
        }

        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            if (!Set.Appearances[slot])
                Set.IgnoreMask |= (1u << slot);

        ParseSuccess = true;
        ParseError.clear();
        DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS", _worldPacket);
    }
    catch (std::exception const& ex)
    {
        ParseSuccess = false;
        ParseError = ex.what();
        DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS", _worldPacket);
    }

    _worldPacket.rfinish();
}

void TransmogOutfitUpdateSituations::Read()
{
    CapturePayloadDebugInfo(_worldPacket, PayloadSize, PayloadPreviewHex);

    ParseSuccess = false;

    try
    {
        _worldPacket >> SetID;
        _worldPacket >> Npc;

        std::size_t rposAfterGuid = _worldPacket.rpos();

        uint32 count = 0;
        _worldPacket >> count;

        TC_LOG_DEBUG("network.opcode.transmog", "CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS diag: setId={} npc={} rposAfterGuid={} count={}",
            SetID, Npc.ToString(), rposAfterGuid, count);

        Situations.resize(count);
        for (TransmogOutfitSituationEntry& entry : Situations)
        {
            _worldPacket >> entry.SituationID;
            _worldPacket >> entry.SpecID;
            _worldPacket >> entry.LoadoutID;
            _worldPacket >> entry.EquipmentSetID;
        }

        ParseSuccess = true;
        ParseError.clear();
        DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS", _worldPacket);
    }
    catch (std::exception const& ex)
    {
        ParseSuccess = false;
        ParseError = ex.what();
        DiagnosticReadTrace = BuildDiagnosticReadTrace("CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS", _worldPacket);
    }

    _worldPacket.rfinish();
}

WorldPacket const* TransmogOutfitInfoUpdated::Write()
{
    _worldPacket << uint32(SetID);
    _worldPacket << uint64(Guid);
    return &_worldPacket;
}

WorldPacket const* TransmogOutfitNewEntryAdded::Write()
{
    _worldPacket << uint32(SetID);
    _worldPacket << uint64(Guid);
    return &_worldPacket;
}

WorldPacket const* TransmogOutfitSituationsUpdated::Write()
{
    _worldPacket << uint32(SetID);
    _worldPacket << uint64(Guid);
    return &_worldPacket;
}

WorldPacket const* TransmogOutfitSlotsUpdated::Write()
{
    _worldPacket << uint32(SetID);
    _worldPacket << uint64(Guid);
    return &_worldPacket;
}

WorldPacket const* AccountTransmogUpdate::Write()
{
    _worldPacket << Bits<1>(IsFullUpdate);
    _worldPacket << Bits<1>(IsSetFavorite);
    _worldPacket << Size<uint32>(FavoriteAppearances);
    _worldPacket << Size<uint32>(NewAppearances);
    if (!FavoriteAppearances.empty())
        _worldPacket.append(FavoriteAppearances.data(), FavoriteAppearances.size());

    if (!NewAppearances.empty())
        _worldPacket.append(NewAppearances.data(), NewAppearances.size());

    return &_worldPacket;
}
}
