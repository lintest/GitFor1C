#ifndef __CLIPMNGR_H__
#define __CLIPMNGR_H__

#include "stdafx.h"
#include "AddInNative.h"
#include <git2.h> 

class GitManager : public AddInNative {

	class Signature {
	public:
		Signature(const std::string& name, const std::string& email)
			: m_name(name), m_email(email) {}

		virtual ~Signature() {}

		int now(git_signature** out) {
			return git_signature_now(out, m_name.c_str(), m_email.c_str());
		}
	private:
		std::string m_name = nullptr;
		std::string m_email = nullptr;
	};

private:
	git_repository* m_repo = nullptr;
	Signature* m_author = nullptr;
	Signature* m_committer = nullptr;
	bool error(VH var);

private:
	static std::vector<std::u16string> names;
	GitManager();

public:
	virtual ~GitManager();

private:
	bool close();
	void setAuthor(const std::string& name, const std::string& email);
	void setCommitter(const std::string& name, const std::string& email);
	long getEncoding(VH blob);
	bool isBinary(VH blob, VH encoding);
	void blob(VH id, VH encoding);
	std::wstring getFullpath(const std::wstring& path);
	std::string init(const std::string& path);
	std::string clone(const std::string& url, const std::string& path);
	std::string info(const std::string& msg);
	std::string open(const std::string& path);
	std::string find(const std::string& path);
	std::string add(const std::string& append, const std::string& remove);
	std::string reset(const std::string& filelist);
	std::string remove(const std::string& filelist);
	std::string discard(const std::string& filelist);
	std::string commit(const std::string& msg);
	std::string history(const std::string& msg);
	std::string diff(const std::u16string s1, const std::u16string& s2);
	std::string file(const std::string& path, bool full);
	std::string tree(const std::string& id);
	std::string remoteList();
	std::string signature();
	std::string status();
};

#endif //__CLIPMNGR_H__
