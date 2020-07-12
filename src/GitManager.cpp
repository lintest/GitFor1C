#include "GitManager.h"
#include "json_ext.h"

#include <stdexcept>
#include <iostream>
#include <cstring>
#include <string>
#include <thread>

#ifdef WIN32
#include <windows.h>
#include <conio.h>
#endif // WIN32

#pragma comment(lib, "git2")
#pragma comment(lib, "msvcrtd")
#pragma comment(lib, "crypt32")
#pragma comment(lib, "rpcrt4")
#pragma comment(lib, "winhttp")

GitManager::GitManager(AddInNative* addin)
{
	m_addin = addin;
	git_libgit2_init();
}

GitManager::~GitManager()
{
	git_libgit2_shutdown();
}

std::wstring GitManager::init(const std::wstring &path, bool is_bare)
{
	int error = git_repository_init(&m_repo, WC2MB(path).c_str(), is_bare);
	return {};
}
