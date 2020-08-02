#include "script_component.hpp"

params ["_target","_player","_entity"];

[
	[["SSS_SignalConfirm","确认信号",ICON_LAND_GREEN,{
		private _entity = _this # 2;
		_entity setVariable ["SSS_signalApproved",true,true];
		_entity setVariable ["SSS_needConfirmation",false,true];
	},{(_this # 2) getVariable "SSS_needConfirmation"},{},_entity] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_SignalDeny","搜寻新信号",ICON_SEARCH_YELLOW,{
		private _entity = _this # 2;
		_entity setVariable ["SSS_signalApproved",false,true];
		_entity setVariable ["SSS_needConfirmation",false,true];
	},{(_this # 2) getVariable "SSS_needConfirmation"},{},_entity] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_SlingLoadSelect","选择要吊挂的物品",[ICON_SLINGLOAD,HEX_GREEN],{
		params ["_target","_player","_entity"];

		private _vehicle = _entity getVariable "SSS_vehicle";
		private _position = _entity getVariable ["SSS_slingLoadPosition",getPos _vehicle];
		private _objects = (nearestObjects [_position,SSS_slingLoadWhitelist,SSS_setting_slingLoadSearchRadius]) select {
			_vehicle canSlingLoad _x && {side _vehicle getFriend side _x >= 0.6}
		};

		if (_objects isEqualTo []) exitWith {
			NOTIFY_LOCAL(_entity,"附近没有可吊挂的物品");
		};

		private _cfgVehicles = configFile >> "CfgVehicles";
		private _rows = [];
		
		{
			private _cfg = _cfgVehicles >> typeOf _x;
			private _name = getText (_cfg >> "displayName");
			private _icon = getText (_cfg >> "picture");

			if (toLower _icon in ["","picturething"]) then {
				_icon = ICON_BOX;
			};

			_rows pushBack [[_name,_icon],"","","",str (_x distance _position) + "m"];
		} forEach _objects;

		["选择物品",[
			["LISTNBOX","可吊挂的物品:",[_rows,0,12]]
		],{
			params ["_values","_args"];
			_values params ["_index"];
			_args params ["_entity","_objects"];

			_entity setVariable ["SSS_slingLoadObject",_objects # _index,true];
			_entity setVariable ["SSS_slingLoadReady",false,true];
		},{},[_entity,_objects]] call EFUNC(CDS,dialog);
	},{(_this # 2) getVariable "SSS_slingLoadReady"},{},_entity] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_Unhook","脱钩",[ICON_SLINGLOAD,HEX_YELLOW],{
		_this call FUNC(selectPosition);
	},{!isNull getSlingLoad (_this # 2 # 0 getVariable "SSS_vehicle")},{},[_entity,"UNHOOK"]] call ace_interact_menu_fnc_createAction,[],_target],
	
	[["SSS_RTB","返回基地(RTB)",ICON_HOME,{
		(_this # 2) call EFUNC(support,requestTransportHelicopter);
	},{(_this # 2 # 0) getVariable "SSS_awayFromBase"},{},[_entity,"RTB"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_Pickup","接取",ICON_SMOKE,{
		_this call FUNC(selectPosition);
	},{true},{},[_entity,"PICKUP"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_Land","降落",ICON_LAND,{
		_this call FUNC(selectPosition);
	},{true},{},[_entity,"LAND"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_LandEngOff","降落并关闭引擎",ICON_LAND_ENG_OFF,{
		_this call FUNC(selectPosition);
	},{true},{},[_entity,"LAND_ENG_OFF"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_Move","移动",ICON_MOVE,{
		_this call FUNC(selectPosition);
	},{true},{},[_entity,"MOVE"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_Hover","悬停/索降",ICON_ROPE,{
		_this call FUNC(selectPosition);
	},{true},{},[_entity,"HOVER"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_Loiter","环绕",ICON_LOITER,{
		_this call FUNC(selectPosition);
	},{true},{},[_entity,"LOITER"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_SlingLoad","吊挂",ICON_SLINGLOAD,{
		_this call FUNC(selectPosition);
	},{true},{},[_entity,"SLINGLOAD"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_Paradrop","空投",ICON_PARACHUTE,{
		_this call FUNC(selectPosition);
	},{true},{},[_entity,"PARADROP"]] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_Behavior","调整行为",ICON_GEAR,{
		private _entity = _this # 2;

		["调整行为",[
			["SLIDER","飞行高度",[[40,2000,0],_entity getVariable "SSS_flyingHeight"]],
			["COMBOBOX","速度",[["限速","常速","全速"],_entity getVariable "SSS_speedMode"]],
			["COMBOBOX","交战模式",[["自由开火","停火"],_entity getVariable "SSS_combatMode"]],
			["CHECKBOX","探照灯",_entity getVariable "SSS_lightsOn"],
			["CHECKBOX","防撞灯",_entity getVariable "SSS_collisionLightsOn"],
			["BUTTON","肃静!",SHUP_UP_BUTTON_CODE]
		],{
			_this call EFUNC(common,changeBehavior);
		},{},_entity] call EFUNC(CDS,dialog);
	},{true},{},_entity] call ace_interact_menu_fnc_createAction,[],_target],

	[["SSS_SITREP","报告状态",ICON_SITREP,{
		private _entity = _this # 2;
		private _vehicle = _entity getVariable ["SSS_vehicle",objNull];
		private _message = format ["位置坐标: %1<br />%2",mapGridPosition _vehicle,switch true do {
			case (!canMove _vehicle) : {"状态: 失能"};
			case (damage _vehicle > 0) : {"状态: 受损"};
			default {"状态: 良好"};
		}];

		NOTIFY_LOCAL(_entity,_message);

		private _marker = createMarkerLocal [format ["SSS_%1$%2$%3",_vehicle,CBA_missionTime,random 1],getPos _vehicle];
		_marker setMarkerShapeLocal "ICON";
		_marker setMarkerTypeLocal "mil_box";
		_marker setMarkerColorLocal "ColorGrey";
		_marker setMarkerTextLocal (_entity getVariable "SSS_callsign");
		_marker setMarkerAlphaLocal 1;
		
		[{
			params ["_args","_PFHID"];
			_args params ["_vehicle","_marker"];

			private _alpha = markerAlpha _marker - 0.005;
			_marker setMarkerAlphaLocal _alpha;

			if (alive _vehicle) then {
				_marker setMarkerPosLocal getPosVisual _vehicle;
			};

			if (_alpha <= 0) then {
				_PFHID call CBA_fnc_removePerFrameHandler;
				deleteMarkerLocal _marker;
			};
		},0.1,[_vehicle,_marker]] call CBA_fnc_addPerFrameHandler;
	},{true},{},_entity] call ace_interact_menu_fnc_createAction,[],_target]
]
