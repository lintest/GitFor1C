#include "stdafx.h"

#ifdef _WINDOWS
#pragma setlocale("ru-RU" )
#else //_WINDOWS
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <errno.h>
#include <iconv.h>
#include <sys/time.h>
#endif //_WINDOWS

#include "GitControl.h"
#include "version.h"

const wchar_t* GitControl::m_ExtensionName = L"GitFor1C";

const std::vector<AddInBase::Alias> GitControl::m_PropList{
	Alias(eVersion  , false , L"Version"   , L"Версия"),
};

const std::vector<AddInBase::Alias> GitControl::m_MethList{
	Alias(eInit     , 2, true  , L"Init"       , L"Init"   ),
	Alias(eClone    , 2, true  , L"Clone"      , L"Clone"  ),
	Alias(eFind     , 1, true  , L"Find"       , L"Find"   ),
	Alias(eOpen     , 1, true  , L"Open"       , L"Open"   ),
	Alias(eInfo     , 1, true  , L"Info"       , L"Info"   ),
	Alias(eCommit   , 1, true  , L"Commit"     , L"Commit" ),
	Alias(eStatus   , 0, true  , L"Status"     , L"Status" ),
	Alias(eAdd      , 1, true  , L"Add"        , L"Add"),
	Alias(eRemove   , 1, true  , L"Remove"     , L"Remove"),
};

/////////////////////////////////////////////////////////////////////////////
// ILanguageExtenderBase
//---------------------------------------------------------------------------//
bool GitControl::GetPropVal(const long lPropNum, tVariant* pvarPropVal)
{
	switch (lPropNum) {
	case eVersion:
		return VA(pvarPropVal) << MB2WC(VER_FILE_VERSION_STR);
	default:
		return false;
	}
}

#define ASSERT(c, m) if (!(c)) { addError(m); return false; }

//---------------------------------------------------------------------------//
bool GitControl::SetPropVal(const long lPropNum, tVariant* pvarPropVal)
{
	return false;
}
//---------------------------------------------------------------------------//
bool GitControl::CallAsProc(const long lMethodNum, tVariant* paParams, const long lSizeArray)
{
	return false;
}
//---------------------------------------------------------------------------//
bool GitControl::CallAsFunc(const long lMethodNum, tVariant* pvarRetValue, tVariant* paParams, const long lSizeArray)
{
	switch (lMethodNum) {
	case eInit:
		return VA(pvarRetValue) << m_manager.init(VarToStr(paParams), VarToBool(paParams + 1));
	case eClone:
		return VA(pvarRetValue) << m_manager.clone(VarToStr(paParams), VarToStr(paParams + 1));
	case eOpen:
		return VA(pvarRetValue) << m_manager.open(VarToStr(paParams));
	case eFind:
		return VA(pvarRetValue) << m_manager.find(VarToStr(paParams));
	case eInfo:
		return VA(pvarRetValue) << m_manager.info(VarToStr(paParams));
	case eCommit:
		return VA(pvarRetValue) << m_manager.commit(VarToStr(paParams));
	case eAdd:
		return VA(pvarRetValue) << m_manager.add(VarToStr(paParams));
	case eRemove:
		return VA(pvarRetValue) << m_manager.remove(VarToStr(paParams));
	case eStatus:
		return VA(pvarRetValue) << m_manager.status();
	default:
		return false;
	}
}
//---------------------------------------------------------------------------//
static bool DefInt(tVariant* pvar, int value = 0)
{
	TV_VT(pvar) = VTYPE_I4;
	TV_I4(pvar) = value;
	return true;
}
static bool DefBool(tVariant* pvar, bool value = false)
{
	TV_VT(pvar) = VTYPE_BOOL;
	TV_BOOL(pvar) = value;
	return true;
}
//---------------------------------------------------------------------------//
bool GitControl::GetParamDefValue(const long lMethodNum, const long lParamNum, tVariant* pvarParamDefValue)
{
	switch (lMethodNum) {
	case eInit: if (lParamNum == 1) return DefBool(pvarParamDefValue);
	}
	return false;
}
