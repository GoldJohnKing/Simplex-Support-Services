#include "script_component.hpp"

params ["_smoke"];

private _smokeColor = getArray (configfile >> "CfgAmmo" >> typeOf _smoke >> "smokeColor");
_smokeColor deleteAt 3;

private _rgbDistances = [];
{
	_x params ["_name","_RGB"];
	_rgbDistances pushBack [_smokeColor distance _RGB,_name];
} forEach [
	["白色",[1,1,1]],
	["黑色",[0,0,0]],
	["红色",[0.8438,0.1383,0.1353]],
	["橙色",[0.6697,0.2275,0.10053]],
	["黄色",[0.9883,0.8606,0.0719]],
	["绿色",[0.2125,0.6258,0.4891]],
	["蓝色",[0.1183,0.1867,1]],
	["紫色",[0.4341,0.1388,0.4144]]
];
_rgbDistances sort true;

_rgbDistances # 0 # 1

