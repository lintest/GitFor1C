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
	Alias(eVersion  , false , L"version"   , L"version"),
};

const std::vector<AddInBase::Alias> GitControl::m_MethList{
	Alias(eInit  , 2, true  , L"init"       , L"init"),
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
