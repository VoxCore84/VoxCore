/*
 * Copyright 2023 Hoff
 */

#include "Hoff.h"

Position Hoff::GetTargetFollowPosition(Unit* ParentUnit, EFollowAngle Angle, float Distance)
{
    float FollowAngle = 0.f;
    switch (Angle) {
    default:
    case FOLLOW_ANGLE_FRONT:
        FollowAngle = static_cast<float>(2 * M_PI);
        break;
    case FOLLOW_ANGLE_FRONT_LEFT:
        FollowAngle = static_cast<float>(M_PI / 4);
        break;
    case FOLLOW_ANGLE_FRONT_RIGHT:
        FollowAngle = static_cast<float>((7 * M_PI) / 4);
        break;
    case FOLLOW_ANGLE_LEFT:
        FollowAngle = static_cast<float>(M_PI / 2);
        break;
    case FOLLOW_ANGLE_RIGHT:
        FollowAngle = static_cast<float>((3 * M_PI) / 2);
        break;
    case FOLLOW_ANGLE_BACK:
        FollowAngle = static_cast<float>(M_PI);
        break;
    case FOLLOW_ANGLE_BACK_LEFT:
        FollowAngle = static_cast<float>((3 * M_PI) / 4);
        break;
    case FOLLOW_ANGLE_BACK_RIGHT:
        FollowAngle = static_cast<float>((5 * M_PI) / 4);
        break;
    }

    FollowAngle += ParentUnit->GetOrientation();

    Position OutPos = ParentUnit->GetPosition();
    OutPos.m_positionX += Distance * cosf(FollowAngle);
    OutPos.m_positionY += Distance * sinf(FollowAngle);

    float destx, desty, destz, ground, floor;
    destx = OutPos.m_positionX;
    desty = OutPos.m_positionY;

    ground = ParentUnit->GetMapHeight(destx, desty, MAX_HEIGHT);
    floor = ParentUnit->GetMapHeight(destx, desty, OutPos.m_positionZ);
    destz = std::fabs(ground - OutPos.m_positionZ) <= std::fabs(floor - OutPos.m_positionZ) ? ground : floor;

    float step = Distance / 10.0f;

    for (uint8 j = 0; j < 10; ++j)
    {
        // do not allow too big z changes
        if (std::fabs(OutPos.m_positionZ - destz) > 6)
        {
            destx -= step * std::cos(FollowAngle);
            desty -= step * std::sin(FollowAngle);
            ground = ParentUnit->GetMap()->GetHeight(ParentUnit->GetPhaseShift(), destx, desty, MAX_HEIGHT, true);
            floor = ParentUnit->GetMap()->GetHeight(ParentUnit->GetPhaseShift(), destx, desty, OutPos.m_positionZ, true);
            destz = std::fabs(ground - OutPos.m_positionZ) <= std::fabs(floor - OutPos.m_positionZ) ? ground : floor;
        }
        // we have correct destz now
        else
        {
            OutPos.Relocate(destx, desty, destz);
            break;
        }
    }

    Trinity::NormalizeMapCoord(OutPos.m_positionX);
    Trinity::NormalizeMapCoord(OutPos.m_positionY);
    ParentUnit->UpdateGroundPositionZ(OutPos.m_positionX, OutPos.m_positionY, OutPos.m_positionZ);

    return OutPos;
}
