#ifndef __CLIPMNGR_H__
#define __CLIPMNGR_H__

#include "stdafx.h"
#include <git2.h> 

class GitManager {

	class Signature {
	public:
		Signature(std::wstring name, std::wstring email)
			: m_name(WC2MB(name)), m_email(WC2MB(email)) {}

		virtual ~Signature() {}

		int now(git_signature** out) {
			return git_signature_now(out, m_name.c_str(), m_email.c_str());
		}
	private:
		std::string m_name = nullptr;
		std::string m_email = nullptr;
	};

private:
	AddInNative* m_addin = nullptr;
	git_repository* m_repo = nullptr;
	Signature* m_author = nullptr;
	Signature* m_committer = nullptr;
	bool error(tVariant* pvar);

public:
	GitManager(AddInNative* addin);
	virtual ~GitManager();
	bool close();
	int getEncoding(tVariant* pvar);
	bool isBinary(tVariant* pvarData, tVariant* pvarEncoding);
	bool blob(const std::wstring& id, tVariant* pvarEncoding, tVariant* pvarRetValue);
	bool setAuthor(const std::wstring& name, const std::wstring& email);
	bool setCommitter(const std::wstring& name, const std::wstring& email);
	std::wstring fullpath(const std::wstring& path);
	std::wstring init(const std::wstring& path, bool is_bare);
	std::wstring clone(const std::wstring& url, const std::wstring& path);
	std::wstring info(const std::wstring& msg);
	std::wstring open(const std::wstring& path);
	std::wstring find(const std::wstring& path);
	std::wstring add(const std::wstring& append, const std::wstring& remove);
	std::wstring reset(const std::wstring& filelist);
	std::wstring remove(const std::wstring& filelist);
	std::wstring discard(const std::wstring& filelist);
	std::wstring commit(const std::wstring& msg);
	std::wstring history(const std::wstring& msg);
	std::wstring diff(const std::wstring& s1, const std::wstring& s2);
	std::wstring file(const std::wstring& path, bool full);
	std::wstring tree(const std::wstring& msg);
	std::wstring signature();
	std::wstring status();
};

#endif //__CLIPMNGR_H__
