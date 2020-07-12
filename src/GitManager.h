#ifndef __CLIPMNGR_H__
#define __CLIPMNGR_H__

#include "stdafx.h"
#include <git2.h> 

class GitManager {
private:
	AddInNative* m_addin = nullptr;
	git_repository* m_repo = nullptr;
public:
	GitManager(AddInNative* addin);
	virtual ~GitManager();
	std::wstring init(const std::wstring& path, bool is_bare);
};

#endif //__CLIPMNGR_H__
