#ifndef __CLIPMNGR_H__
#define __CLIPMNGR_H__

#include "stdafx.h"
#include <git2.h> 

class GitManager {
private:
	AddInNative* m_addin = nullptr;
	git_repository* m_repo = nullptr;
	static std::wstring success(int error);
	static std::wstring error(std::string message);
public:
	GitManager(AddInNative* addin);
	virtual ~GitManager();
	std::wstring init(const std::wstring& path, bool is_bare);
	std::wstring clone(const std::wstring& url, const std::wstring& path);
	std::wstring info(const std::wstring& msg);
	std::wstring open(const std::wstring& path);
	std::wstring find(const std::wstring& path);
	std::wstring add(const std::wstring& msg);
	std::wstring remove(const std::wstring& msg);
	std::wstring commit(const std::wstring& msg);
	std::wstring status();
};

#endif //__CLIPMNGR_H__
