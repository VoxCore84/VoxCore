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

#include "WorldSession.h"
#include "GameTime.h"
#include "HotfixPackets.h"
#include "Log.h"
#include "MapUtils.h"
#include "World.h"

void WorldSession::HandleDBQueryBulk(WorldPackets::Hotfix::DBQueryBulk& dbQuery)
{
    DB2StorageBase const* store = sDB2Manager.GetStorage(dbQuery.TableHash);
    for (WorldPackets::Hotfix::DBQueryBulk::DBQueryRecord const& record : dbQuery.Queries)
    {
        WorldPackets::Hotfix::DBReply dbReply;
        dbReply.TableHash = dbQuery.TableHash;
        dbReply.RecordID = record.RecordID;

        if (store && store->HasRecord(record.RecordID))
        {
            dbReply.Status = DB2Manager::HotfixRecord::Status::Valid;
            dbReply.Timestamp = GameTime::GetGameTime();
            store->WriteRecord(record.RecordID, GetSessionDbcLocale(), dbReply.Data);

            if (std::vector<DB2Manager::HotfixOptionalData> const* optionalDataEntries = sDB2Manager.GetHotfixOptionalData(dbQuery.TableHash, record.RecordID, GetSessionDbcLocale()))
            {
                for (DB2Manager::HotfixOptionalData const& optionalData : *optionalDataEntries)
                {
                    dbReply.Data << uint32(optionalData.Key);
                    dbReply.Data.append(optionalData.Data.data(), optionalData.Data.size());
                }
            }
        }
        else
        {
            TC_LOG_TRACE("network", "CMSG_DB_QUERY_BULK: {} requested non-existing entry {} in datastore: {}", GetPlayerInfo(), record.RecordID, dbQuery.TableHash);
            dbReply.Timestamp = GameTime::GetGameTime();
        }

        SendPacket(dbReply.Write());
    }
}

void WorldSession::SendAvailableHotfixes()
{
    // Bug #6: This sends ~7.7MB of hotfix IDs (966K entries * 8 bytes) at login.
    // Confirmed safe: SendPacket enqueues via lock-free MPSC queue (WorldSocket::SendPacket)
    // and actual wire send happens on the network thread. No login sequence blocking.
    WorldPackets::Hotfix::AvailableHotfixes availableHotfixes;
    availableHotfixes.VirtualRealmAddress = GetVirtualRealmAddress();

    for (auto const& [pushId, push] : sDB2Manager.GetHotfixData())
    {
        if (!(push.AvailableLocalesMask & (1 << GetSessionDbcLocale())))
            continue;

        availableHotfixes.Hotfixes.insert(push.Records.front().ID);
    }

    SendPacket(availableHotfixes.Write());
}

void WorldSession::HandleHotfixRequest(WorldPackets::Hotfix::HotfixRequest& hotfixQuery)
{
    // Chunk hotfix responses to avoid exceeding the ByteBuffer size limit.
    // With 1M+ hotfix_data rows the monolithic response easily exceeds 100MB.
    static constexpr std::size_t MaxContentPerPacket = 50 * 1024 * 1024; // 50MB per chunk

    // Bug #5: Server-side sanity cap on hotfix request count.
    // The existing HotfixRequest::Read validation caps at sDB2Manager.GetHotfixCount(),
    // but this additional limit protects against worst-case memory/CPU when the hotfix
    // dataset itself is very large. Current count is ~966K; cap provides headroom.
    // Can be moved to worldserver.conf (Hotfix.MaxRequestCount) for runtime tuning.
    static constexpr uint32 MaxHotfixRequestCount = 1000000;
    if (hotfixQuery.Hotfixes.size() > MaxHotfixRequestCount)
    {
        TC_LOG_WARN("network", "WorldSession::HandleHotfixRequest: {} requested {} hotfixes (cap: {}), truncating",
            GetPlayerInfo(), hotfixQuery.Hotfixes.size(), MaxHotfixRequestCount);
        hotfixQuery.Hotfixes.resize(MaxHotfixRequestCount);
    }

    DB2Manager::HotfixContainer const& hotfixes = sDB2Manager.GetHotfixData();
    auto hotfixQueryResponse = std::make_unique<WorldPackets::Hotfix::HotfixConnect>();

    for (int32 hotfixId : hotfixQuery.Hotfixes)
    {
        if (DB2Manager::HotfixPush const* hotfixRecords = Trinity::Containers::MapGetValuePtr(hotfixes, hotfixId))
        {
            for (DB2Manager::HotfixRecord const& hotfixRecord : hotfixRecords->Records)
            {
                if (!(hotfixRecord.AvailableLocalesMask & (1 << GetSessionDbcLocale())))
                    continue;

                WorldPackets::Hotfix::HotfixConnect::HotfixData& hotfixData = hotfixQueryResponse->Hotfixes.emplace_back();
                hotfixData.Record = hotfixRecord;
                if (hotfixRecord.HotfixStatus == DB2Manager::HotfixRecord::Status::Valid)
                {
                    DB2StorageBase const* storage = sDB2Manager.GetStorage(hotfixRecord.TableHash);
                    if (storage && storage->HasRecord(uint32(hotfixRecord.RecordID)))
                    {
                        std::size_t pos = hotfixQueryResponse->HotfixContent.size();
                        storage->WriteRecord(uint32(hotfixRecord.RecordID), GetSessionDbcLocale(), hotfixQueryResponse->HotfixContent);

                        if (std::vector<DB2Manager::HotfixOptionalData> const* optionalDataEntries = sDB2Manager.GetHotfixOptionalData(hotfixRecord.TableHash, hotfixRecord.RecordID, GetSessionDbcLocale()))
                        {
                            for (DB2Manager::HotfixOptionalData const& optionalData : *optionalDataEntries)
                            {
                                hotfixQueryResponse->HotfixContent << uint32(optionalData.Key);
                                hotfixQueryResponse->HotfixContent.append(optionalData.Data.data(), optionalData.Data.size());
                            }
                        }

                        hotfixData.Size = hotfixQueryResponse->HotfixContent.size() - pos;
                    }
                    else if (std::vector<uint8> const* blobData = sDB2Manager.GetHotfixBlobData(hotfixRecord.TableHash, hotfixRecord.RecordID, GetSessionDbcLocale()))
                    {
                        hotfixData.Size = blobData->size();
                        hotfixQueryResponse->HotfixContent.append(blobData->data(), blobData->size());
                    }
                    else
                        // Do not send Status::Valid when we don't have a hotfix blob for current locale
                        hotfixData.Record.HotfixStatus = storage ? DB2Manager::HotfixRecord::Status::RecordRemoved : DB2Manager::HotfixRecord::Status::Invalid;
                }
            }
        }

        // Flush current chunk when content exceeds threshold
        if (hotfixQueryResponse->HotfixContent.size() >= MaxContentPerPacket)
        {
            SendPacket(hotfixQueryResponse->Write());
            hotfixQueryResponse = std::make_unique<WorldPackets::Hotfix::HotfixConnect>();
        }
    }

    // Send remaining records (or empty response if no hotfixes matched)
    SendPacket(hotfixQueryResponse->Write());
}
