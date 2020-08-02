#include "script_component.hpp"

params ["_player","_entity","_request","_position"];

if (isNull _entity) exitWith {};

if (count _position isEqualTo 2) then {
	_position set [2,0];
};

private _approvalReturn = [_position] call (_entity getVariable ["SSS_requestCondition",{true}]);
private _denialText = "拒绝请求。";
private _approval = if (_approvalReturn isEqualType true) then {
	_approvalReturn
} else {
	_approvalReturn params [["_bool",false,[false]],["_reason","",[""]]];
	_denialText = _denialText + _reason;
	_bool
};

if (!_approval) exitWith {
	NOTIFY_LOCAL(_entity,_denialText);
};

switch (_entity getVariable "SSS_supportType") do {
	case "artillery" : {
		private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

		if (!alive _vehicle) exitWith {};

		if (!(_vehicle isKindOf "B_Ship_MRLS_01_base_F") && {!(_position inRangeOfArtillery [[_vehicle],_request])}) exitWith {
			private _string = ["<t color='#f4ca00'>超出支援范围。</t>无法执行任务。","超出支援范围。无法执行任务。"] select SSS_setting_useChatNotifications;
			NOTIFY_LOCAL(_entity,_string);
		};

		private _nearbyArtillery = ([_player,"artillery"] call FUNC(availableEntities)) select {
			private _otherVehicle = _x getVariable ["SSS_vehicle",objNull];

			if (alive _otherVehicle) then {
				private _magazines = if (_otherVehicle isKindOf "B_Ship_MRLS_01_base_F") then {
					["magazine_Missiles_Cruise_01_x18","magazine_Missiles_Cruise_01_Cluster_x18"]
				} else {
					getArtilleryAmmo [_otherVehicle]
				};

				_request in _magazines && {
				_vehicle != _otherVehicle && {
				_vehicle distance2D _otherVehicle < (_x getVariable "SSS_coordinationDistance") && {
				(_x getVariable "SSS_cooldown") isEqualTo 0}}}
			} else {
				false
			};
		};
		
		["Fire Mission Parameters - " + mapGridPosition _position,[
			["SLIDER","Rounds",[[1,_entity getVariable "SSS_maxRounds",0],1]],
			["SLIDER","Random dispersion radius",[[0,250,0],0]],
			["SLIDER",["Coordination amount","Request fire mission from similar nearby artillery"],[[0,count _nearbyArtillery,0],0],true,{},count _nearbyArtillery > 0]
		],{
			params ["_values","_args"];
			_values params ["_rounds","_dispersion","_coordinateCount"];
			_args params ["_entity","_request","_position","_nearbyArtillery"];

			private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

			if (alive _vehicle) then {
				[_entity,_request,_position,_rounds,_dispersion] remoteExecCall [QEFUNC(support,requestArtillery),_vehicle];
			};

			if (_coordinateCount > 0) then {
				_nearbyArtillery = _nearbyArtillery select {!isNull _x && {(_x getVariable "SSS_cooldown") isEqualTo 0}};
				for "_i" from 0 to (_coordinateCount - 1) do {
					private _extraEntity = _nearbyArtillery # _i;
					private _extraVehicle = _extraEntity getVariable ["SSS_vehicle",objNull];
					if (alive _extraVehicle) then {
						[_extraEntity,_request,_position,_rounds,_dispersion] remoteExecCall [QEFUNC(support,requestArtillery),_extraVehicle];
					};
				};
			};
		},{REQUEST_CANCELLED;},[_entity,_request,_position,_nearbyArtillery]] call EFUNC(CDS,dialog);
	};

	case "CASDrone" : {
		if (SSS_setting_GiveUAVTerminal) then {
			private _UAVTerminal = switch (_entity getVariable "SSS_side") do {
				case west : {"B_UavTerminal"};
				case east : {"O_UavTerminal"};
				case independent : {"I_UavTerminal"};
				case civilian : {"C_UavTerminal"};
			};

			if !(_UAVTerminal in (assignedItems player)) then {
				player linkItem _UAVTerminal;
			};
		};

		["无人机支援参数",[
			["COMBOBOX","环绕方向",[[["顺时针","",ICON_CLOCKWISE],["逆时针","",ICON_COUNTER_CLOCKWISE]],0]],
			["SLIDER","环绕半径",[[800,2500,0],1000]],
			["SLIDER","飞行高度",[[600,2500,0],1000]]
		],{
			params ["_values","_args"];
			_values params ["_loiterDirection","_loiterRadius","_loiterAltitude"];
			_args params ["_entity","_position"];

			[_entity,_position,_loiterDirection,_loiterRadius,_loiterAltitude] remoteExecCall [QEFUNC(support,requestCASDrone),2];
		},{REQUEST_CANCELLED;},[_entity,_position]] call EFUNC(CDS,dialog);
	};

	case "CASGunship" : {
		["Gunship Request Parameters",[
			["SLIDER","Loiter radius",[[800,2500,0],1000]],
			["SLIDER","Altitude above position",[[600,2500,0],1000]]
		],{
			params ["_values","_args"];
			_values params ["_loiterRadius","_loiterAltitude"];
			_args params ["_entity","_position"];

			[_entity,_position,_loiterRadius,_loiterAltitude] remoteExecCall [QEFUNC(support,requestCASGunship),2];
		},{REQUEST_CANCELLED;},[_entity,_position]] call EFUNC(CDS,dialog);
	};

	case "CASHelicopter" : {
		private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

		if (!alive _vehicle) exitWith {};

		switch (_request) do {
			case "LOITER";
			case 3 : {
				["Loiter parameters",[
					["SLIDER","Loiter radius",[[150,1500,0],200]],
					["COMBOBOX","Loiter direction",[[["Clockwise","",ICON_CLOCKWISE],["Counter-Clockwise","",ICON_COUNTER_CLOCKWISE]],0]]
				],{
					params ["_values","_args"];
					_args params ["_entity","_request","_position"];

					private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

					if (!alive _vehicle) exitWith {};

					[_entity,_request,_position,_values] remoteExecCall [QEFUNC(support,requestCASHelicopter),_vehicle];
				},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
			};

			default {
				[_entity,_request,_position] remoteExecCall [QEFUNC(support,requestCASHelicopter),_vehicle];
			};
		};
	};

	case "CASPlane" : {
		// Get directions not blocked by terrain
		_position set [2,1];
		private _positionASL = AGLtoASL _position;
		private _bearingList = [[0,"N"],[45,"NE"],[90,"E"],[135,"SE"],[180,"S"],[225,"SW"],[270,"W"],[315,"NW"]] apply {
			private _testPos = AGLtoASL (_position getPos [600,_x # 0]);
			_testPos set [2,_positionASL # 2 + 350];
			if (terrainIntersectASL [_positionASL,_testPos]) then {
				[_x # 1,"地形阻挡进场","",RGBA_ORANGE]
			} else {
				[_x # 1]
			};
		};

		["近距离空中支援(CAS)参数 - " + mapGridPosition _position,[
			["COMBOBOX",["进场方向","橙色表示无法从该方向进场"],[_bearingList,0],false],
			["COMBOBOX","地图位置或其他信号",[[
				["地图位置","",ICON_MAP],
				["镭射指引","",ICON_TARGET],
				["烟雾弹指引","",ICON_SMOKE],
				["红外指引","",ICON_STROBE]
			],0],false,{
				params ["_currentValue","_args","_ctrl"];
				if (_currentValue isEqualTo 2) then {
					[2,{true}] call EFUNC(CDS,setEnableCondition);
				} else {
					[2,{false}] call EFUNC(CDS,setEnableCondition);
				};
			}],
			["COMBOBOX","烟雾颜色",[[
				"白色","黑色",
				["红色","","",[0.9,0,0,1]],
				["橙色","","",[0.85,0.4,0,1]],
				["黄色","","",[0.85,0.85,0,1]],
				["绿色","","",[0,0.8,0,1]],
				["蓝色","","",[0,0,1,1]],
				["紫色","","",[0.75,0.15,0.75,1]]
			],0],false,{},{false}]
		],{
			params ["_values","_args"];

			(_args + _values) remoteExecCall [QEFUNC(support,requestCASPlane),2];
		},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
	};

	case "transportHelicopter" : {
		private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

		if (!alive _vehicle) exitWith {};

		switch (_request) do {
			case "HOVER";
			case 5 : {
				["悬停参数",[
					["SLIDER",["悬停高度","高度设置过低可能导致飞机与地面相撞"],[[1,2000,0],15],false],
					["CHECKBOX","就绪后索降",true,false]
				],{
					params ["_values","_args"];
					_args params ["_entity","_request","_position"];

					private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

					if (!alive _vehicle) exitWith {};

					[_entity,_request,_position,_values] remoteExecCall [QEFUNC(support,requestTransportHelicopter),_vehicle];
				},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
			};

			case "LOITER";
			case 6 : {
				["环绕参数",[
					["SLIDER","环绕半径",[[150,1500,0],200]],
					["COMBOBOX","环绕方向",[[["顺时针","",ICON_CLOCKWISE],["逆时针","",ICON_COUNTER_CLOCKWISE]],0]]
				],{
					params ["_values","_args"];
					_args params ["_entity","_request","_position"];

					private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

					if (!alive _vehicle) exitWith {};

					[_entity,_request,_position,_values] remoteExecCall [QEFUNC(support,requestTransportHelicopter),_vehicle];
				},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
			};

			case "PARADROP" : {
				["空投参数",[
					["SLIDER",["跳伞间隔","两个单位之间跳伞时间间隔"],[[0,5,1],1]],
					["SLIDER","AI开伞高度",[[100,2000,0],200]]
				],{
					params ["_values","_args"];
					_args params ["_entity","_request","_position"];

					private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

					if (!alive _vehicle) exitWith {};

					[_entity,_request,_position,_values] remoteExecCall [QEFUNC(support,requestTransportHelicopter),_vehicle];
				},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
			};

			default {
				[_entity,_request,_position] remoteExecCall [QEFUNC(support,requestTransportHelicopter),_vehicle];
			};
		};
	};

	case "transportLandVehicle" : {
		private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

		if (!alive _vehicle) exitWith {};

		[_entity,_request,_position] remoteExecCall [QEFUNC(support,requestTransportLandVehicle),_vehicle];
	};

	case "transportMaritime" : {
		private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

		if (!alive _vehicle) exitWith {};

		[_entity,_request,_position] remoteExecCall [QEFUNC(support,requestTransportMaritime),_vehicle];
	};

	case "transportPlane" : {
		private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

		if (!alive _vehicle) exitWith {};

		switch (_request) do {
			case "PARADROP";
			case 2 : {
				["Paradrop parameters",[
					["SLIDER",["Jump delay","Seconds between each unit jumping out"],[[0,5,1],1]],
					["SLIDER","AI opening height",[[100,2000,0],200]]
				],{
					params ["_values","_args"];
					_args params ["_entity","_request","_position"];

					private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

					if (!alive _vehicle) exitWith {};

					[_entity,_request,_position,_values] remoteExecCall [QEFUNC(support,requestTransportPlane),_vehicle];
				},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
			};

			case "LOITER";
			case 3 : {
				["Loiter parameters",[
					["SLIDER","Loiter radius",[[500,1500,0],500]],
					["COMBOBOX","Loiter direction",[[["Clockwise","",ICON_CLOCKWISE],["Counter-Clockwise","",ICON_COUNTER_CLOCKWISE]],0]]
				],{
					params ["_values","_args"];
					_args params ["_entity","_request","_position"];

					private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

					if (!alive _vehicle) exitWith {};

					[_entity,_request,_position,_values] remoteExecCall [QEFUNC(support,requestTransportPlane),_vehicle];
				},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
			};

			default {
				[_entity,_request,_position] remoteExecCall [QEFUNC(support,requestTransportPlane),_vehicle];
			};
		};
	};

	case "transportVTOL" : {
		private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

		if (!alive _vehicle) exitWith {};

		switch (_request) do {
			case "PARADROP";
			case 5 : {
				["空投参数",[
					["SLIDER",["跳伞间隔","两个单位之间跳伞时间间隔"],[[0,5,1],1]],
					["SLIDER","AI开伞高度",[[100,2000,0],200]]
				],{
					params ["_values","_args"];
					_args params ["_entity","_request","_position"];

					private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

					if (!alive _vehicle) exitWith {};

					[_entity,_request,_position,_values] remoteExecCall [QEFUNC(support,requestTransportPlane),_vehicle];
				},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
			};

			case "LOITER";
			case 6 : {
				["环绕参数",[
					["SLIDER","环绕半径",[[500,1500,0],500]],
					["COMBOBOX","环绕方向",[[["顺时针","",ICON_CLOCKWISE],["逆时针","",ICON_COUNTER_CLOCKWISE]],0]]
				],{
					params ["_values","_args"];
					_args params ["_entity","_request","_position"];

					private _vehicle = _entity getVariable ["SSS_vehicle",objNull];

					if (!alive _vehicle) exitWith {};

					[_entity,_request,_position,_values] remoteExecCall [QEFUNC(support,requestTransportVTOL),_vehicle];
				},{REQUEST_CANCELLED;},[_entity,_request,_position]] call EFUNC(CDS,dialog);
			};

			default {
				[_entity,_request,_position] remoteExecCall [QEFUNC(support,requestTransportVTOL),_vehicle];
			};
		};
	};

	case "logisticsAirdrop" : {
		[_entity,_position,_player] call EFUNC(support,requestLogisticsAirdrop);
	};
};
