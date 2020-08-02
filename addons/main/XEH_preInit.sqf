#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"

// Admin
["SSS_setting_adminFullAccess","CHECKBOX",
	["Give admins access to all supports","Admins will be able to use every support available, even if services aren't shown/enabled"],
	["Simplex Support Services","Admin"],
	true, // _valueInfo
	true, // _isGlobal
	{}, //_script
	false // _needRestart
] call CBA_fnc_addSetting;

["SSS_setting_adminLimitSide","CHECKBOX",
	["Limit admin access to side","Limit the admin access to the current side of the admin"],
	["Simplex Support Services","Admin"],
	false,
	false,
	{},
	false
] call CBA_fnc_addSetting;

// Core
["SSS_setting_GiveUAVTerminal","CHECKBOX",
	["Give UAV Terminal on drone request","Gives CAS Drone requesters a UAV terminal if they don't have one"],
	["Simplex Support Services","Core"],
	true,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_directActionRequirement","CHECKBOX",
	["Require access item/condition for direct action","When disabled, anyone can interact directly with transports or logistics booths"],
	["Simplex Support Services","Core"],
	false,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_removeSupportOnVehicleDeletion","CHECKBOX",
	["Remove support on vehicle deletion","If disabled, any physical support vehicles capable of respawning will simply respawn"],
	["Simplex Support Services","Core"],
	true,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_deleteVehicleOnEntityRemoval","CHECKBOX",
	["Delete vehicle on entity removal","When a support entity is deleted/removed, its physical vehicle will be deleted"],
	["Simplex Support Services","Core"],
	false,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_cleanupCrew","CHECKBOX",
	["Delete old vehicle crew on respawn","When a vehicle is no longer usable, the crew will de-spawn instead of leaving the vehicle"],
	["Simplex Support Services","Core"],
	true,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_resetVehicleOnRTB","CHECKBOX",
	["Reset vehicle on RTB","When a vehicle arrives back at base, it is repaired, fuel is refilled, and ammo is restored"],
	["Simplex Support Services","Core"],
	true,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_restoreCrewOnRTB","CHECKBOX",
	["Restore vehicle crew on RTB","Restores health to all crew and revives any dead crew when a vehicle returns to base"],
	["Simplex Support Services","Core"],
	true,
	true,
	{},
	false
] call CBA_fnc_addSetting;

// Sling Loading
["SSS_setting_slingLoadWhitelist","EDITBOX",
	["Sling load whitelist","Only these classnames will be searched for at sling load request locations"],
	["Simplex Support Services","Sling Loading"],
	"",
	true,
	{missionNamespace setVariable["SSS_slingLoadWhitelist",(([_this] call CBA_fnc_removeWhitespace) splitString ",") apply {toLower _x},true]},
	false
] call CBA_fnc_addSetting;

["SSS_setting_slingLoadSearchRadius","SLIDER",
	["Sling load search radius","Determines how far from the request position to search for objects"],
	["Simplex Support Services","Sling Loading"],
	[10,200,100,0],
	true,
	{},
	false
] call CBA_fnc_addSetting;

// Milsim mode
["SSS_setting_milsimModeArtillery","CHECKBOX",
	["Enable milsim mode - Artillery","Require map grid coordinates on requests"],
	["Simplex Support Services","Milsim Mode"],
	false,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_milsimModeCAS","CHECKBOX",
	["Enable milsim mode - CAS","Require map grid coordinates on requests"],
	["Simplex Support Services","Milsim Mode"],
	false,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_milsimModeTransport","CHECKBOX",
	["Enable milsim mode - Transport","Require map grid coordinates on requests"],
	["Simplex Support Services","Milsim Mode"],
	false,
	true,
	{},
	false
] call CBA_fnc_addSetting;

["SSS_setting_milsimModeLogistics","CHECKBOX",
	["Enable milsim mode - Logistics","Require map grid coordinates on requests"],
	["Simplex Support Services","Milsim Mode"],
	false,
	true,
	{},
	false
] call CBA_fnc_addSetting;

// Personal
["SSS_setting_useChatNotifications","CHECKBOX",
	["Use chat notifications","Disables custom notification system"],
	["Simplex Support Services","Personal"],
	false,
	false,
	{},
	false
] call CBA_fnc_addSetting;

// Master array
SSS_entities = [];

// Transport action
["SSS_commissioned",{
	params ["_vehicle"];

	private _entity = _vehicle getVariable ["SSS_parentEntity",objNull];

	if (!alive _vehicle || isNull _entity || {(_entity getVariable "SSS_service") != "Transport"}) exitWith {};

	private _action = ["SSS_transport","运输",ICON_TRANSPORT,{},
		EFUNC(interaction,transportVehicleActionCondition),
		EFUNC(interaction,transportVehicleActionChildren)
	] call ace_interact_menu_fnc_createAction;

	[_vehicle,0,["ACE_MainActions"],_action] call ace_interact_menu_fnc_addActionToObject;
	[_vehicle,1,["ACE_SelfActions"],_action] call ace_interact_menu_fnc_addActionToObject;
}] call CBA_fnc_addEventHandler;

["SSS_logisticsStationBooth",{
	params ["_entity","_booth"];

	if (isNull _entity) exitWith {};

	private _assignedStations = _booth getVariable ["SSS_assignedStations",[]];
	private _index = _assignedStations pushBack _entity;
	_booth setVariable ["SSS_assignedStations",_assignedStations];

	private _action = ["SSS_logisticsStations:" + str _index,_entity getVariable "SSS_callsign",ICON_BOX,{
		_this call EFUNC(support,requestLogisticsStation)
	},{
		params ["_target","_player","_entity"];

		if (SSS_setting_directActionRequirement && {!(_entity in ([_player,"logistics"] call EFUNC(interaction,availableEntities)))}) exitWith {false};
		
		!isNull _entity && SSS_showLogisticsStations && {(_entity getVariable "SSS_side") == side group _player}
	},{},_entity] call ace_interact_menu_fnc_createAction;

	[_booth,0,["ACE_MainActions"],_action] call ace_interact_menu_fnc_addActionToObject;
	[_booth,1,["ACE_SelfActions"],_action] call ace_interact_menu_fnc_addActionToObject;
}] call CBA_fnc_addEventHandler;

// Zeus handling
["ModuleCurator_F","init",{
	params ["_zeus"];

	_zeus addEventHandler ["CuratorWaypointDeleted",{
		params ["_zeus","_group"];

		if (_group getVariable ["SSS_protectWaypoints",false]) then {
			private _vehicle = vehicle leader _group;
			private _entity = _vehicle getVariable ["SSS_parentEntity",objNull];

			if (isNull _entity) exitWith {};

			SSS_ERROR("Support vehicle waypoint was deleted!");

			switch (_entity getVariable "SSS_supportType") do {
				case "CASHelicopter";
				case "transportHelicopter";
				case "transportLandVehicle";
				case "transportMaritime";
				case "transportPlane";
				case "transportVTOL" : {
					[_entity,false] call EFUNC(common,updateMarker);
					INTERRUPT(_entity,_vehicle);
				};

				default {
					_vehicle setVariable ["SSS_WPDone",true,true];
				};
			};
		};
	}];
}] call CBA_fnc_addClassEventHandler;

// 'show' variables
{
	if (isNil _x) then {
		missionNamespace setVariable [_x,true];
	};
} forEach [
	"SSS_showArtillery",
	"SSS_showCAS",
	"SSS_showTransport",
	"SSS_showCASDrones",
	"SSS_showCASGunships",
	"SSS_showCASHelicopters",
	"SSS_showCASPlanes",
	"SSS_showTransportHelicopters",
	"SSS_showTransportLandVehicles",
	"SSS_showTransportMaritime",
	"SSS_showTransportPlanes",
	"SSS_showTransportVTOLs",
	"SSS_showLogistics",
	"SSS_showLogisticsAirdrops",
	"SSS_showLogisticsStations"
];

ADDON = true;
